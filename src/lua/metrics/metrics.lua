local monitoring = require "metrics.monitoring"
local logging = require "middleware.logging"

local cache_status = ngx.var.upstream_cache_status
if cache_status then
    monitoring.cache_status_total:inc(1, { ngx.var.host, cache_status })
end

logging.send_log()
