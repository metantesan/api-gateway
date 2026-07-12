from http.server import HTTPServer, BaseHTTPRequestHandler
import json, threading

log_store = {"logs": [], "last": None}
lock = threading.Lock()

class LogHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        try:
            data = json.loads(body)
        except Exception:
            data = {"raw": body.decode("utf-8", errors="replace")}
        with lock:
            log_store["logs"].append(data)
            log_store["last"] = data
        self.send_response(200)
        self.end_headers()

    def log_message(self, format, *args):
        pass

class QueryHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        with lock:
            payload = json.dumps(log_store)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(payload.encode())

    def log_message(self, format, *args):
        pass

log_server = HTTPServer(("0.0.0.0", 5044), LogHandler)
query_server = HTTPServer(("0.0.0.0", 5045), QueryHandler)

threading.Thread(target=log_server.serve_forever, daemon=True).start()
threading.Thread(target=query_server.serve_forever, daemon=True).start()

threading.Event().wait()
