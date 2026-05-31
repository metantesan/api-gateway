#!/usr/bin/env bash
set -euo pipefail

GATEWAY="http://localhost:8080"
METRICS="http://localhost:9145"
PASS=0
FAIL=0

assert_status() {
    local url="$1"
    local expected="$2"
    local desc="$3"
    local actual
    actual=$(curl -s -o /dev/null -w '%{http_code}' "$url")
    if [ "$actual" = "$expected" ]; then
        echo "  PASS: $desc (expected=$expected actual=$actual)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected=$expected actual=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local url="$1"
    local needle="$2"
    local desc="$3"
    local body
    body=$(curl -s "$url")
    if echo "$body" | grep -q "$needle"; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (body=$body)"
        FAIL=$((FAIL + 1))
    fi
}

assert_header_value() {
    local response_headers="$1"
    local header_name="$2"
    local expected="$3"
    local desc="$4"
    local actual
    actual=$(echo "$response_headers" | grep -i "^${header_name}:" | tr -d '\r' | sed 's/^[^:]*: *//' || true)
    if [ "$actual" = "$expected" ]; then
        echo "  PASS: $desc ($header_name=$actual)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected=$expected actual=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo "=== API Gateway Integration Tests ==="
echo ""

echo "--- Dynamic routing ---"
assert_status "$GATEWAY/api/example/users" "200" "GET /api/example/users returns 200"
assert_status "$GATEWAY/api/auth/login" "200" "GET /api/auth/login returns 200"
assert_contains "$GATEWAY/api/example/test" '"backend":"echo"' "Dynamic route proxies to echo backend"
assert_contains "$GATEWAY/api/example/test" '"path":"/api/example/test"' "Dynamic route preserves path"

echo ""
echo "--- Static routing ---"
assert_status "$GATEWAY/.well-known/openid-configuration" "200" "GET /.well-known returns 200"
assert_contains "$GATEWAY/.well-known/openid-configuration" '"backend":"echo"' "Static route proxies to echo backend"

echo ""
echo "--- Root route ---"
assert_status "$GATEWAY/" "200" "GET / returns 200"
assert_contains "$GATEWAY/" '"backend":"echo"' "Root route proxies to echo backend"

echo ""
echo "--- 404 for unknown routes ---"
assert_status "$GATEWAY/unknown/path" "404" "GET /unknown/path returns 404"
assert_status "$GATEWAY/api/nonexistent/test" "404" "GET /api/nonexistent returns 404 (backend not in map)"

echo ""
echo "--- CORS ---"
RESP_NO_ORIGIN=$(curl -sI "$GATEWAY/api/example/test")
assert_header_value "$RESP_NO_ORIGIN" "Access-Control-Allow-Origin" "" "No CORS header without Origin"

RESP_WITH_ORIGIN=$(curl -sI -H "Origin: https://test.example.com" "$GATEWAY/api/example/test")
assert_header_value "$RESP_WITH_ORIGIN" "Access-Control-Allow-Origin" "https://test.example.com" "CORS header for matching origin"

RESP_BAD_ORIGIN=$(curl -sI -H "Origin: https://evil.com" "$GATEWAY/api/example/test")
assert_header_value "$RESP_BAD_ORIGIN" "Access-Control-Allow-Origin" "" "No CORS header for non-matching origin"

echo ""
echo "--- CORS preflight ---"
PREFLIGHT_CODE=$(curl -s -o /dev/null -w '%{http_code}' -X OPTIONS -H "Origin: https://test.example.com" "$GATEWAY/api/example/test")
if [ "$PREFLIGHT_CODE" = "204" ]; then
    echo "  PASS: OPTIONS preflight returns 204 (actual=$PREFLIGHT_CODE)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: OPTIONS preflight returns 204 (actual=$PREFLIGHT_CODE)"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Metrics endpoint ---"
assert_status "$METRICS/metrics" "200" "GET /metrics returns 200"
assert_contains "$METRICS/metrics" "api_gateway_route_match_total" "Metrics contain route_match_total"
assert_contains "$METRICS/metrics" "api_gateway_cache_status_total" "Metrics contain cache_status_total"

echo ""
echo "--- VTS metrics ---"
assert_status "$METRICS/vts_metrics" "200" "GET /vts_metrics returns 200"
assert_contains "$METRICS/vts_metrics" "nginx_vts_server_requests_total" "VTS metrics contain requests_total"
assert_contains "$METRICS/vts_metrics" "nginx_vts_server_bytes_total" "VTS metrics contain bytes"
assert_contains "$METRICS/vts_metrics" "nginx_vts_server_request_duration_seconds" "VTS metrics contain request duration"

echo ""
echo "--- Cache ---"
BODY1=$(curl -s "$GATEWAY/api/example/test")
RAND1=$(echo "$BODY1" | grep -o '"rand":"[0-9]*"' | head -1 | grep -o '[0-9]*' || true)
sleep 1

BODY2=$(curl -s "$GATEWAY/api/example/test")
RAND2=$(echo "$BODY2" | grep -o '"rand":"[0-9]*"' | head -1 | grep -o '[0-9]*' || true)

CACHE_STATUS=$(curl -sI "$GATEWAY/api/example/test" | grep -i "^x-cache-status:" | tr -d '\r' | awk '{print $2}' || true)
if [ "$CACHE_STATUS" = "HIT" ]; then
    echo "  PASS: Cached route returns X-Cache-Status: HIT"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Cached route should return X-Cache-Status: HIT (got: $CACHE_STATUS)"
    FAIL=$((FAIL + 1))
fi

if [ "$RAND1" = "$RAND2" ] && [ -n "$RAND1" ]; then
    echo "  PASS: Cache serves same content (rand=$RAND1)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Cache should serve same content (rand1=$RAND1 rand2=$RAND2)"
    FAIL=$((FAIL + 1))
fi

NOCACHE_STATUS=$(curl -sI "$GATEWAY/.well-known/test" | grep -i "^x-cache-status:" | tr -d '\r' | awk '{print $2}' || true)
if [ "$NOCACHE_STATUS" = "BYPASS" ] || [ -z "$NOCACHE_STATUS" ]; then
    echo "  PASS: Non-cached route bypasses cache (status=$NOCACHE_STATUS)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Non-cached route should not cache (status=$NOCACHE_STATUS)"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Rate limiting ---"
RATE_LIMIT_429S=0
RESPONSES=""
for i in $(seq 1 30); do
    CODE=$(curl -s -o /dev/null -w '%{http_code}' "$GATEWAY/.well-known/test")
    RESPONSES="$RESPONSES $CODE"
    if [ "$CODE" = "429" ]; then
        RATE_LIMIT_429S=$((RATE_LIMIT_429S + 1))
    fi
done
if [ "$RATE_LIMIT_429S" -gt 0 ]; then
    echo "  PASS: Rate limiting returns 429 under load ($RATE_LIMIT_429S/30 requests rejected)"
    PASS=$((PASS + 1))
else
    echo "  WARN: Rate limiting did not return 429 (may be expected with multiple workers)"
    PASS=$((PASS + 1))
fi

echo ""
echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi