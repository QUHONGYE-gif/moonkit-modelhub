#!/usr/bin/env python3
"""Local mock of the HuggingFace Hub for modelhub tests.

Endpoints:
  GET/HEAD /hello                              -> 200 "hello world"
  GET/HEAD /redirect                           -> 302 -> /hello
  GET/HEAD /echo-headers                       -> 200 JSON of received headers
  GET/HEAD /api/models/<repo>                  -> repo metadata (id/sha/siblings)
  GET/HEAD /api/models/<repo>/revision/<rev>   -> {"sha": "commit-<rev>", siblings}
  GET/HEAD /<repo>/resolve/<rev>/<file>        -> 302 -> /cdn/<etag>/<file>
  GET/HEAD /cdn/<etag>/<file>                  -> 200/206 file bytes (ETag + Range)
  GET /cdn/<etag>/<file>?interrupt_after=N     -> close connection after N bytes
"""

import hashlib
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

FIXTURES = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "tests", "fixtures"
)
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
        for key, value in (extra or {}).items():
            self.send_header(key, value)
        self.end_headers()
        if self.command != "HEAD" and data:
            self.wfile.write(data)

    def _fixture_path(self, repo, filename):
        root = os.path.realpath(FIXTURES)
        path = os.path.realpath(os.path.join(root, repo, filename))
        if os.path.commonpath([root, path]) != root or not os.path.isfile(path):
            return None
        return path

    def _repo_siblings(self, repo):
        dir_path = os.path.join(FIXTURES, repo)
        if not os.path.isdir(dir_path):
            return None
        return [{"rfilename": f} for f in sorted(os.listdir(dir_path))]

    def _route(self, path, query):
        if path == "/hello":
            return 200, "hello world", None
        if path == "/redirect":
            return 302, "", {"Location": "/hello"}
        if path == "/echo-headers":
            headers = {k: v for k, v in self.headers.items()}
            return 200, json.dumps(headers, indent=2), None

        if path.startswith("/api/models/"):
            parts = path.strip("/").split("/")
            if len(parts) == 3:
                siblings = self._repo_siblings(parts[2])
                if siblings is None:
                    return 404, "not found", None
                return (
                    200,
                    json.dumps(
                        {
                            "id": parts[2],
                            "sha": "commit-main",
                            "private": False,
                            "downloads": 1,
                            "likes": 0,
                            "siblings": siblings,
                        }
                    ),
                    None,
                )
            if len(parts) == 5 and parts[3] == "revision":
                repo, rev = parts[2], parts[4]
                siblings = self._repo_siblings(repo)
                if siblings is None:
                    return 404, "not found", None
                return (
                    200,
                    json.dumps(
                        {
                            "id": repo,
                            "sha": "commit-" + rev,
                            "private": False,
                            "downloads": 1,
                            "likes": 0,
                            "siblings": siblings,
                        }
                    ),
                    None,
                )
            if len(parts) == 5 and parts[3] == "tree":
                repo = parts[2]
                siblings = self._repo_siblings(repo)
                if siblings is None:
                    return 404, "not found", None
                files = []
                for sibling in siblings:
                    fixture = self._fixture_path(repo, sibling["rfilename"])
                    with open(fixture, "rb") as f:
                        content = f.read()
                    files.append(
                        {
                            "type": "file",
                            "path": sibling["rfilename"],
                            "size": len(content),
                            "oid": hashlib.sha256(content).hexdigest(),
                        }
                    )
                return 200, json.dumps(files), None

        # /<repo>/resolve/<rev>/<file>
        parts = path.strip("/").split("/")
        if len(parts) >= 4 and parts[1] == "resolve":
            repo, rev, filename = parts[0], parts[2], "/".join(parts[3:])
            rev = rev if rev.startswith("commit-") else "commit-" + rev
            fixture = self._fixture_path(repo, filename)
            if fixture is None:
                return 404, "entry not found", None
            with open(fixture, "rb") as f:
                content = f.read()
            etag = hashlib.sha256(content).hexdigest()
            return (
                302,
                "",
                {
                    "Location": "/cdn/%s/%s?commit=%s"
                    % (etag, filename, rev)
                },
            )

        # /cdn/<etag>/<file>
        if path.startswith("/cdn/"):
            parts = path.strip("/").split("/")
            if len(parts) >= 3:
                etag, filename = parts[1], "/".join(parts[2:])
                fixture = self._find_fixture(filename)
                if fixture is None:
                    return 404, "entry not found", None
                with open(fixture, "rb") as f:
                    content = f.read()
                extra = {"ETag": '"%s"' % etag, "X-Linked-Etag": '"%s"' % etag}
                commit = query.get("commit", [None])[0]
                if commit is not None:
                    extra["X-Repo-Commit"] = commit
                range_header = self.headers.get("Range")
                if range_header and range_header.startswith("bytes="):
                    spec = range_header[len("bytes="):].split("-", 1)
                    start = int(spec[0]) if spec[0] else 0
                    end = (
                        int(spec[1])
                        if len(spec) > 1 and spec[1]
                        else len(content) - 1
                    )
                    part = content[start : end + 1]
                    extra["Content-Range"] = "bytes %d-%d/%d" % (
                        start,
                        end,
                        len(content),
                    )
                    return 206, part, extra
                interrupt = query.get("interrupt_after", [None])[0]
                if interrupt is not None and self.command != "HEAD":
                    self.send_response(200)
                    self.send_header("Content-Type", "text/plain; charset=utf-8")
                    self.send_header("Content-Length", str(len(content)))
                    for key, value in extra.items():
                        self.send_header(key, value)
                    self.end_headers()
                    self.wfile.write(content[: int(interrupt)])
                    self.wfile.flush()
                    self.close_connection = True
                    return None
                return 200, content, extra

        return 404, "not found", None

    def _find_fixture(self, filename):
        for repo in os.listdir(FIXTURES):
            path = os.path.join(FIXTURES, repo, filename)
            if os.path.isfile(path):
                return path
        return None

    def _handle(self):
        parsed = urlparse(self.path)
        result = self._route(parsed.path, parse_qs(parsed.query))
        if result is None:
            return
        code, body, extra = result
        ctype = (
            "application/json"
            if isinstance(body, str) and body.lstrip().startswith(("{", "["))
            else "text/plain; charset=utf-8"
        )
        self._send(code, body, ctype, extra)

    def do_GET(self):
        self._handle()

    def do_HEAD(self):
        self._handle()


def main():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(
        "mock hub listening on 127.0.0.1:%d (fixtures=%s)" % (PORT, FIXTURES),
        file=sys.stderr,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
