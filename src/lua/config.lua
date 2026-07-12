local lyaml = require "lyaml"

local _M = {}

local config_path = os.getenv("GWCONF") or "/etc/gwconf/gateway.yaml"

local routes = {}
local cors_allowed_origins = {}
local logging = { enabled = false, endpoint = "", timeout_ms = 2000 }

function _M.load()
    local f, err = io.open(config_path, "r")
    if not f then
        ngx.log(ngx.ERR, "failed to open config file: ", config_path, ": ", err)
        return nil, err
    end
    local content = f:read("*a")
    f:close()

    local ok, parsed = pcall(lyaml.load, content)
    if not ok then
        ngx.log(ngx.ERR, "failed to parse config: ", parsed)
        return nil, parsed
    end

    local parsed_routes = parsed.routes or {}
    routes = {}

    for i, route in ipairs(parsed_routes) do
        if route.match then
            routes[i] = {
                name = route.name or ("route_" .. i),
                match_pattern = route.match,
                backends = route.backends,
                backend = route.backend,
                rate_limit = route.rate_limit,
                cache = route.cache,
            }
        end
    end

    cors_allowed_origins = {}
    if parsed.cors and parsed.cors.allowed_origins then
        for _, origin in ipairs(parsed.cors.allowed_origins) do
            cors_allowed_origins[origin] = true
        end
    end

    if parsed.logging then
        logging = {
            enabled = parsed.logging.enabled or false,
            endpoint = parsed.logging.endpoint or "",
            timeout_ms = parsed.logging.timeout_ms or 2000,
        }
    end

    ngx.log(ngx.INFO, "loaded config with ", #routes, " routes from ", config_path)
    return true
end

function _M.get_routes()
    return routes
end

function _M.is_cors_allowed(domain)
    return cors_allowed_origins[domain] ~= nil
end

function _M.get_logging()
    return logging
end

return _M
