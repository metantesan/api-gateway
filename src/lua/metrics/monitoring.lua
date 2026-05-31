local prometheus = require("prometheus").init("prometheus_metrics", { prefix = "api_gateway_" })

local M = {}

M.route_match_total = prometheus:counter("route_match_total", "Total number of route matches", {"host", "status", "appname"})
M.cache_status_total = prometheus:counter("cache_status_total", "Cache status total", {"host", "status"})
M.prometheus = prometheus

return M