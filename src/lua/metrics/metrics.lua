local monitoring = require "metrics.monitoring"

local cache_status = ngx.var.upstream_cache_status
if cache_status then
    monitoring.cache_status_total:inc(1, { ngx.var.host, cache_status })
end

require("middleware.logging").send_log()