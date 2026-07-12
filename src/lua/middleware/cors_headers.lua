local cors_origin = ngx.var.cors_origin
local cors_credentials = ngx.var.cors_credentials

ngx.header["Access-Control-Allow-Origin"] = cors_origin
ngx.header["Access-Control-Allow-Credentials"] = cors_credentials

local method = ngx.req.get_method()
if method == "OPTIONS" and cors_origin and cors_origin ~= "" then
    ngx.header["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS, PUT, DELETE, PATCH"
    ngx.header["Access-Control-Allow-Headers"] = "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization"
    ngx.header["Access-Control-Max-Age"] = "1728000"
    ngx.header["Content-Type"] = "text/plain; charset=utf-8"
    ngx.header["Content-Length"] = 0
    return ngx.exit(204)
end

require("middleware.logging").capture_response_headers()