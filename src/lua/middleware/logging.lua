local cjson = require "cjson.safe"
local config = require "config"

local _M = {}

local MAX_BODY_SIZE = 10 * 1024 * 1024

function _M.capture_request()
    ngx.req.read_body()
    local body = ngx.req.get_body_data() or ""
    if #body > MAX_BODY_SIZE then
        body = string.sub(body, 1, MAX_BODY_SIZE)
    end
    ngx.ctx.req_body = body
    ngx.ctx.req_headers = ngx.req.get_headers()
end

function _M.capture_response_headers()
    ngx.ctx.resp_headers = ngx.resp.get_headers()
end

function _M.capture_response_body()
    local chunk, eof = ngx.arg[1], ngx.arg[2]
    if chunk and chunk ~= "" then
        local buf = ngx.ctx.resp_buf or ""
        if #buf + #chunk > MAX_BODY_SIZE then
            chunk = string.sub(buf .. chunk, 1, MAX_BODY_SIZE)
            ngx.ctx.resp_buf = chunk
            ngx.ctx.resp_overflow = true
        else
            ngx.ctx.resp_buf = buf .. chunk
        end
    end
    if eof then
        ngx.var.resp_body = ngx.ctx.resp_buf or ""
    end
end

function _M.send_log()
    local logging = config.get_logging()
    if not logging.enabled or logging.endpoint == "" then
        return
    end

    if ngx.var.backend_url == "" then
        return
    end

    local http = require "resty.http"

    local payload = {
        remote_addr      = ngx.var.remote_addr,
        time_local       = ngx.var.time_local,
        request_line     = ngx.var.request,
        status           = ngx.status,
        appname          = ngx.var.appname or "",
        backend          = ngx.var.backend_name or "",
        request_headers  = ngx.ctx.req_headers,
        request_body     = ngx.ctx.req_body or "",
        response_headers = ngx.ctx.resp_headers,
        response_body    = ngx.var.resp_body or ""
    }

    local function send(premature, data)
        if premature then return end

        local httpc = http.new()
        httpc:set_timeout(logging.timeout_ms)

        local res, err = httpc:request_uri(logging.endpoint, {
            method  = "POST",
            body    = cjson.encode(data),
            headers = {
                ["Content-Type"]   = "application/json",
                ["Connection"]     = "close"
            }
        })

        if not res then
            ngx.log(ngx.ERR, "log_to_ls error: ", err)
            return
        end

        local ok_close, close_err = httpc:close()
        if not ok_close then
            ngx.log(ngx.ERR, "failed to close socket: ", close_err)
        end
    end

    local ok, err = ngx.timer.at(0, send, payload)
    if not ok then
        ngx.log(ngx.ERR, "failed to create timer: ", err)
    end
end

return _M
