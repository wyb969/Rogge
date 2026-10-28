#!/usr/bin/env python3
import http.server, socketserver, os, sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
ROOT = sys.argv[2] if len(sys.argv) > 2 else "export/web"

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
        # Helpful for mobile / Godot web (safe without threads)
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
    print(f"SERVING http://0.0.0.0:{PORT}/ from {os.getcwd()}", flush=True)
    httpd.serve_forever()
