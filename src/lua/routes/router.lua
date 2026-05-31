local config = require "config"
local monitoring = require "metrics.monitoring"

local ngx_var = ngx.var
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_INFO = ngx.INFO
local ngx_re_match = ngx.re.match

local function trim_trailing_slash(s)
    if s and string.sub(s, -1) == "/" then
        return string.sub(s, 1, -2)
    end
    return s
end

local routes = config.get_routes()
local uri = ngx_var.uri

for i, route in ipairs(routes) do
    local m, err = ngx_re_match(uri, route.match_pattern, "jo")
    if m then
        ngx_log(ngx_INFO, "matched route: ", route.match_pattern)

        local backend_url = nil
        local appname = ""

        if route.backends then
            appname = m[1] or ""
            backend_url = route.backends[appname]
        elseif route.backend then
            backend_url = route.backend
            appname = "static"
        end

        if not backend_url then
            ngx_log(ngx_ERR, "no backend found for route: ", route.match_pattern, " appname: ", appname)
            ngx.status = 404
            ngx.say("No backend found")
            return ngx.exit(ngx.HTTP_NOT_FOUND)
        end

        ngx_var.appname = appname
        ngx_var.backend_url = trim_trailing_slash(backend_url)

        if route.cache then
            local ttl = route.cache
            if type(ttl) == "table" then
                ttl = ttl.ttl or 600
            else
                ttl = tonumber(ttl) or 600
            end
            ngx_var.cache_key = ngx_var.host .. uri
            ngx_var.cache_bypass = 0
            ngx_var.cache_nocache = 0
        else
            ngx_var.cache_bypass = 1
            ngx_var.cache_nocache = 1
        end

        if route.rate_limit then
            local ratelimit = require "middleware.ratelimit"
            ratelimit.handler(route.rate_limit, i)
        end

        monitoring.route_match_total:inc(1, { ngx_var.host, "matched", appname })
        return
    end
end

ngx_var.cache_bypass = 1
ngx_var.cache_nocache = 1

ngx_log(ngx_ERR, "no route matched for URI: ", uri)
ngx.status = 404
ngx.say("Not found")
ngx.exit(ngx.HTTP_NOT_FOUND)