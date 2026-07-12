if ngx.status == 204 or ngx.var.backend_url == "" then
    return
end
require("metrics.metrics")
require("middleware.logging").send_log()
