dofile("conf/lua/middleware/cors_headers.lua")
require("middleware.logging").capture_response_headers()
