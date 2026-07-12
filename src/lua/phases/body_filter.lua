if ngx.status == 204 then
    return
end
require("middleware.logging").capture_response_body()
