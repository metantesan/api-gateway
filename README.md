# API Gateway

A dynamic API Gateway built on OpenResty, configurable via YAML.

## Features

*   **Config-Driven Routing:** Define routes in a YAML config file with regex pattern matching.
*   **Dynamic Backends:** Route requests to different backends based on URL patterns with capture groups.
*   **Per-Route Rate Limiting:** Configure rate limits (requests/sec + burst) per route.
*   **CORS Handling:** Define allowed origins in config. Automatically handles preflight requests.
*   **Per-Route Caching:** Enable response caching per route with configurable TTL. Responses are served from cache on subsequent requests (HIT/MISS/BYPASS via `X-Cache-Status` header).
*   **Request/Response Logging:** Capture full request and response data (headers, bodies) and send asynchronously to Logstash/Elasticsearch. Each route has a `name` field for log identification.
*   **Prometheus Metrics:** Built-in metrics endpoint for monitoring.
*   **Dockerized:** Containerized with Docker and Docker Compose.

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

### Quick Start

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/metantesan/api-gateway.git
    cd api-gateway
    ```

2.  **Create a config file:**
    ```bash
    cp gwconf.example.yaml gateway.yaml
    ```
    Edit `gateway.yaml` to define your routes and backends.

3.  **Start the gateway:**
    ```bash
    docker-compose up -d
    ```

The gateway listens on port **8080** (HTTP) and exposes Prometheus metrics on port **9145**.

## Configuration

Configuration is loaded from a YAML file specified by the `GWCONF` environment variable (default: `/etc/gwconf/gateway.yaml`).

### Routes

Routes are matched in order. The first matching route wins.

```yaml
routes:
  # Dynamic backend: first regex capture group selects the backend
  - name: api
    match: "^/api/([a-zA-Z0-9_-]+)(/.*)?$"
    backends:
      example: "http://example-service:3000"
      auth: "http://auth-service:3000"
    rate_limit:
      rps: 5
      burst: 5

  # Static backend: all matching requests go to one URL
  - name: sso
    match: "^/.well-known/.*$"
    backend: "http://sso-service:3000"
    rate_limit:
      rps: 5
      burst: 5

  # Root route
  - name: landing
    match: "^/$"
    backend: "http://landing-service:3000"
```

**Dynamic backends:** When a route has `backends` (a map), the first capture group from the regex is used as a key to look up the backend URL. For example, `/api/example/users` matches `^/api/([a-zA-Z0-9_-]+)(/.*)?$` with capture group `"example"`, which maps to `http://example-service:3000`.

**Static backends:** When a route has `backend` (a string), all matching requests are proxied to that URL.

### Rate Limiting

Add `rate_limit` to any route to enable per-client rate limiting:

```yaml
rate_limit:
  rps: 5      # requests per second
  burst: 5    # burst allowance
```

Rate limits are isolated per route — a rate-limited client on one route can still access other routes.

### Caching

Enable response caching per route. Cached responses include an `X-Cache-Status` header (`HIT`, `MISS`, `BYPASS`, `EXPIRED`).

```yaml
routes:
  # Cache with default TTL (10m)
  - match: "^/api/([a-zA-Z0-9_-]+)(/.*)?$"
    backends:
      example: "http://example-service:3000"
    cache: true

  # Cache with custom TTL (300 seconds)
  - match: "^/$"
    backend: "http://landing-service:3000"
    cache: 300

  # Cache with structured config
  - match: "^/static/.*$"
    backend: "http://static-service:3000"
    cache:
      ttl: 600
```

Routes without `cache` are not cached — the gateway proxies every request directly to the backend.

### Logging

Enable request/response logging to a Logstash (or any HTTP JSON endpoint). Each log entry includes full request and response data with the route name for identification.

```yaml
logging:
  enabled: true
  endpoint: "http://logstash:5044"
  timeout_ms: 2000
```

**JSON payload sent to Logstash:**

```json
{
  "remote_addr": "1.2.3.4",
  "time_local": "12/Jul/2026:10:00:00 +0000",
  "request_line": "GET /api/auth/callback HTTP/1.1",
  "status": 200,
  "appname": "api",
  "backend": "auth",
  "request_headers": { "...": "..." },
  "request_body": "{ ... }",
  "response_headers": { "...": "..." },
  "response_body": "{ ... }"
}
```

| Field | Description |
|-------|-------------|
| `appname` | Route `name` from config (e.g. `api`, `sso`, `landing`) |
| `backend` | Matched backend key for dynamic routes, or route name for static routes |
| `request_headers` | Full client request headers |
| `request_body` | Client request body (truncated to 10MB) |
| `response_headers` | Upstream response headers |
| `response_body` | Upstream response body (truncated to 10MB) |

Logs are sent asynchronously via `ngx.timer` so they don't add latency to the request.

### CORS

Define allowed origins under the `cors` key:

```yaml
cors:
  allowed_origins:
    - "example.com"
    - "api.example.com"
```

Same-origin requests are automatically allowed. Preflight (`OPTIONS`) requests receive proper CORS headers.

### Metrics

Two metrics endpoints are available on port **9145**:

**Lua metrics** (`/metrics`) — application-level:

| Metric | Type | Labels |
|--------|------|--------|
| `api_gateway_route_match_total` | Counter | host, status, appname |
| `api_gateway_cache_status_total` | Counter | host, status |

**VTS metrics** (`/vts_metrics`) — server-level traffic (Prometheus format):

| Metric | Type | Labels |
|--------|------|--------|
| `nginx_vts_server_requests_total` | Counter | code, host |
| `nginx_vts_server_bytes_total` | Counter | host, direction |
| `nginx_vts_server_request_duration_seconds` | Histogram | host |
| `nginx_vts_filter_requests_total` | Counter | filter_name, filter_key |

A **status dashboard** is available at `http://localhost:8080/status` (HTML).

### Monitoring with Grafana

The `docker-compose.yml` includes Prometheus and Grafana for live traffic visualization:

```bash
docker-compose up -d
```

- **Grafana**: [http://localhost:3000](http://localhost:3000) (admin/admin)
- **Prometheus**: [http://localhost:9090](http://localhost:9090)

Grafana comes pre-provisioned with a **"API Gateway - Live Traffic"** dashboard showing:
- Requests/sec with status code breakdown
- Response time percentiles (p50, p95, p99)
- Inbound/outbound traffic bandwidth
- Cache hit ratio gauge
- Rate-limited requests (429)
- Route matches per app

## Testing

Integration tests run the gateway container with a mock backend and logstash mock, verifying routing, caching, CORS, rate limiting, metrics, and logging:

```bash
cd test
docker compose -f docker-compose.test.yml up -d --build
bash run.sh
docker compose -f docker-compose.test.yml down -v
```

Tests run automatically on GitHub Actions for every push and pull request.

## Reloading Configuration

To reload the config without downtime:

```bash
docker-compose kill -s SIGHUP api-gateway
```

This triggers nginx worker restarts, which re-read the config file.

## License

BSD-3-Clause. See [LICENSE](LICENSE) for details.