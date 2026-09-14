#!/usr/bin/env python3
"""Local mock of the HuggingFace Hub for modelhub tests.

Endpoints:
  GET /hello                              -> 200 "hello world"
  GET /redirect                           -> 302 -> /hello
  GET /echo-headers                       -> 200 JSON of received headers
  GET /api/models/<repo>/revision/<rev>   -> {"sha": "commit-<rev>"}
  GET /<repo>/resolve/<rev>/<file>        -> 302 -> /cdn/<etag>/<file>
  GET /cdn/<etag>/<file>                  -> 200/206 file bytes (ETag + Range)
  GET /cdn/<etag>/<file>?interrupt_after=N
                                          -> close connection after N bytes
"""

import hashlib
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

FIXTURES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tests", "fixtures")
PORT = int(os.environ.get("MOCK_PORT", "8765"))


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _send(self, code, body, ctype="text/plain; charset=utf-8", extra=None):
        data = body if isinstance(body, bytes) else body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if data:
            self.wfile.write(data)

    def _fixture_path(self, repo, filename):
        root = os.path.realpath(FIXTURES)
        path = os.path.realpath(os.path.join(root, repo, filename))
        if os.path.commonpath([root, path]) != root or not os.path.isfile(path):
            return None
        return path

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == "/hello":
            self._send(200, "hello world")
            return
        if path == "/redirect":
            self._send(302, "", extra={"Location": "/hello"})
            return
        if path == "/echo-headers":
            headers = {k: v for k, v in self.headers.items()}
            self._send(200, json.dumps(headers, indent=2), "application/json")
            return

        # /api/models/<repo>/revision/<rev>
        if path.startswith("/api/models/"):
            parts = path.strip("/").split("/")
            if len(parts) == 5 and parts[3] == "revision":
                repo, rev = parts[2], parts[4]
                self._send(200, json.dumps({"sha": "commit-" + rev}), "application/json")
                return

        # /<repo>/resolve/<rev>/<file>
        parts = path.strip("/").split("/")
        if len(parts) >= 4 and parts[1] == "resolve":
            repo, rev, filename = parts[0], parts[2], "/".join(parts[3:])
            fixture = self._fixture_path(repo, filename)
            if fixture is None:
                self._send(404, "entry not found")
                return
            with open(fixture, "rb") as f:
                content = f.read()
            etag = hashlib.sha256(content).hexdigest()
            self._send(302, "", extra={"Location": "/cdn/%s/%s" % (etag, filename)})
            return

        # /cdn/<etag>/<file>
        if path.startswith("/cdn/"):
            parts = path.strip("/").split("/")
            if len(parts) >= 3:
                etag, filename = parts[1], "/".join(parts[2:])
                repo = self._repo_for_filename(filename)
                fixture = self._fixture_path(repo, filename) if repo else None
                if fixture is None:
                    self._send(404, "entry not found")
                    return
                with open(fixture, "rb") as f:
                    content = f.read()
                extra = {"ETag": '"%s"' % etag}
                range_header = self.headers.get("Range")
                if range_header and range_header.startswith("bytes="):
                    spec = range_header[len("bytes="):].split("-", 1)
                    start = int(spec[0]) if spec[0] else 0
                    end = int(spec[1]) if len(spec) > 1 and spec[1] else len(content) - 1
                    part = content[start:end + 1]
                    extra["Content-Range"] = "bytes %d-%d/%d" % (start, end, len(content))
                    self._send(206, part, extra=extra)
                    return
                interrupt = query.get("interrupt_after", [None])[0]
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                for k, v in extra.items():
                    self.send_header(k, v)
                self.end_headers()
                if interrupt is not None:
                    self.wfile.write(content[: int(interrupt)])
                    self.wfile.flush()
                    self.close_connection = True
                else:
                    self.wfile.write(content)
                return

        self._send(404, "not found")

    def _repo_for_filename(self, filename):
        for repo in os.listdir(FIXTURES):
            if os.path.isfile(os.path.join(FIXTURES, repo, filename)):
                return repo
        return None


def main():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print("mock hub listening on 127.0.0.1:%d (fixtures=%s)" % (PORT, FIXTURES), file=sys.stderr)
    server.serve_forever()


if __name__ == "__main__":
    main()
