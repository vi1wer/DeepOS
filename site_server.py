#!/usr/bin/env python3
"""Serve the DeepOS site and the current image files."""

from __future__ import annotations

from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SITE = ROOT / "site"
OUT = ROOT / "out"
FILES = {
    "/download/vmlinuz": OUT / "vmlinuz",
    "/download/deepos-rootfs.cpio.gz": OUT / "deepos-rootfs.cpio.gz",
}


class SiteHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(SITE), **kwargs)

    def do_HEAD(self) -> None:
        path = self.path.split("?", 1)[0]
        if path == "/download/version":
            body = self.version_text()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return
        target = FILES.get(path)
        if target is not None:
            self.send_download(target, body=False)
            return
        super().do_HEAD()

    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
        if path == "/download/version":
            body = self.version_text()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        target = FILES.get(path)
        if target is not None:
            self.send_download(target, body=True)
            return
        super().do_GET()

    def version_text(self) -> bytes:
        version = OUT / "VERSION"
        if not version.is_file():
            return "сборка ещё не собрана".encode("utf-8")
        return version.read_text(encoding="utf-8").strip().encode("utf-8")

    def send_download(self, path: Path, body: bool) -> None:
        if not path.is_file():
            self.send_error(404, "File not found")
            return
        size = path.stat().st_size
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(size))
        self.send_header("Content-Disposition", f'attachment; filename="{path.name}"')
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if not body:
            return
        try:
            with path.open("rb") as fh:
                while True:
                    chunk = fh.read(1024 * 1024)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            return


def main() -> None:
    server = ThreadingHTTPServer(("127.0.0.1", 8765), SiteHandler)
    print("DeepOS site http://127.0.0.1:8765/", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
