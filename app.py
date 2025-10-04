#!/usr/bin/env python3.12

import sys
import os
import json
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer


class SimpleHandler(BaseHTTPRequestHandler):
    def _send_json(self, status_code: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{now}] {self.address_string()} - {format % args}")
        sys.stdout.flush()

    def do_GET(self) -> None:  # noqa: N802
        if self.path in ("/", "/health", "/ping"):
            payload = {
                "status": "ok",
                "path": self.path,
                "environment": os.getenv("ENVIRONMENT", "unknown"),
                "project": os.getenv("PROJECT_NAME", "unknown"),
                "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            }
            self._send_json(200, payload)
        else:
            self._send_json(404, {"error": "not found", "path": self.path})


def main() -> None:
    port = int(os.getenv("PORT", "8080"))
    print("=" * 50)
    print("HCM POC API Server Starting...")
    print(f"Python version: {sys.version}")
    print(f"Environment: {os.getenv('ENVIRONMENT', 'unknown')}")
    print(f"Project: {os.getenv('PROJECT_NAME', 'unknown')}")
    print(f"Listening on :{port}")
    print("=" * 50)
    sys.stdout.flush()

    try:
        server = HTTPServer(("0.0.0.0", port), SimpleHandler)
        server.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down...")
        sys.stdout.flush()
    except Exception as e:
        print(f"ERROR: {e}")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
