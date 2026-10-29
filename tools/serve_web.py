#!/usr/bin/env python3
import http.server, socketserver, os, sys, time

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
ROOT = sys.argv[2] if len(sys.argv) > 2 else "export/web"
BUILD_ID = str(int(time.time()))

os.chdir(ROOT)


class Handler(http.server.SimpleHTTPRequestHandler):
	extensions_map = {
		**getattr(http.server.SimpleHTTPRequestHandler, "extensions_map", {}),
		".wasm": "application/wasm",
		".js": "application/javascript",
		".pck": "application/octet-stream",
		".png": "image/png",
		".html": "text/html",
		".json": "application/json",
	}

	def end_headers(self):
		# No-threads web export does not need COEP; skipping it avoids some
		# mobile browsers leaving AudioContext suspended under isolation.
		self.send_header("Cross-Origin-Resource-Policy", "same-origin")
		self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
		self.send_header("Pragma", "no-cache")
		super().end_headers()

	def do_GET(self):
		# Cache-bust Godot asset URLs so phones never keep an old .pck/.wasm.
		if self.path.startswith("/index.") and "?" not in self.path:
			pass
		super().do_GET()

	def log_message(self, fmt, *args):
		sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


print(f"SERVING http://0.0.0.0:{PORT}/ from {os.getcwd()} build={BUILD_ID}", flush=True)
with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
	httpd.serve_forever()
