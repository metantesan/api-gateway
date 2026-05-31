local config = require "config"

local headers = ngx.req.get_headers()
local origin_header = headers["Origin"]
local origin = ""

if origin_header then
    if type(origin_header) == "table" then
        origin = origin_header[1] or ""
    else
        origin = origin_header
    end
end

if origin == "" then
    origin_header = headers["Referer"]
    if origin_header then
        if type(origin_header) == "table" then
            origin = origin_header[1] or ""
        else
            origin = origin_header
        end
    end
end

local origin_host = nil
if origin ~= "" then
    origin_host = string.match(origin, "://([^/]+)")
end

local requested_host = ngx.var.host

if origin_host and requested_host and origin_host == requested_host then
    return
end

if origin ~= "" and origin_host then
    ngx.log(ngx.INFO, "CORS: checking origin_host: ", origin_host, " origin: ", origin)

    if config.is_cors_allowed(origin_host) or config.is_cors_allowed(string.match(origin_host, "([^%.]+%.[^%.]+)$") or origin_host) then
        ngx.var.cors_origin = origin
        ngx.var.cors_credentials = "true"
        ngx.log(ngx.INFO, "CORS: allowed origin: ", origin)
    end
end