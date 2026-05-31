local limit_req = require "resty.limit.req"

local limiters = {}

local function handler(opts, route_idx)
    local rps = opts and opts.rps or 5
    local burst = opts and opts.burst or 5
    local dict_key = "rl_" .. route_idx

    local lim = limiters[dict_key]
    if not lim then
        lim, err = limit_req.new("rate_limiting_store", rps, burst)
        if not lim then
            ngx.log(ngx.ERR, "failed to instantiate limit_req: ", err)
            return ngx.exit(500)
        end
        limiters[dict_key] = lim
    end

    local key = ngx.var.http_authorization or ngx.var.binary_remote_addr
    local delay, err = lim:incoming(key, true)
    if not delay then
        if err == "rejected" then
            return ngx.exit(429)
        end
        ngx.log(ngx.ERR, "failed to limit req: ", err)
        return ngx.exit(500)
    end

    if delay > 0 then
        ngx.sleep(delay)
    end
end

return {
    handler = handler
}