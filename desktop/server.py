#!/usr/bin/env python3
"""Local API and desktop files for the DeepOS shell."""

from __future__ import annotations

import json
import os
import subprocess
import threading
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOST = "127.0.0.1"
PORT = 8765
STATIC = Path("/usr/share/deepos/desktop")
SETTINGS = Path("/root/.deepos/settings")
STATE = {"cwd": "/root"}


def run(cmd: str, cwd: str | None = None, timeout: int = 12) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        shell=True,
        cwd=cwd,
        text=True,
        capture_output=True,
        timeout=timeout,
        executable="/bin/sh",
    )


def read_text(path: str, limit: int = 4000) -> str:
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace")[:limit]
    except OSError:
        return ""


def sysinfo() -> dict:
    osrel = {}
    for line in read_text("/etc/os-release", 2000).splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            osrel[key] = value.strip().strip('"')
    mem = {}
    for line in read_text("/proc/meminfo", 2000).splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            mem[key] = value.strip()
    ip = run("ip -4 -o addr show scope global 2>/dev/null || true").stdout.strip()
    addrs = []
    for line in ip.splitlines():
        parts = line.split()
        if len(parts) >= 4:
            addrs.append({"iface": parts[1], "addr": parts[3]})
    cards = read_text("/proc/asound/cards", 500).strip()
    battery = Path("/sys/class/power_supply")
    power = "ac"
    if battery.is_dir() and any(battery.iterdir()):
        power = "battery"
    uname = run("uname -a").stdout.strip()
    host = read_text("/etc/hostname", 80).strip() or "deepos"
    return {
        "user": "root",
        "host": host,
        "pretty": osrel.get("PRETTY_NAME", "DeepOS"),
        "name": osrel.get("NAME", "DeepOS"),
        "version": osrel.get("VERSION", ""),
        "kernel": uname,
        "mem_total": mem.get("MemTotal", ""),
        "mem_available": mem.get("MemAvailable", ""),
        "addrs": addrs,
        "online": bool(addrs),
        "sound": bool(cards) and "no soundcards" not in cards.lower(),
        "power": power,
        "cwd": STATE["cwd"],
    }


def safe_path(raw: str) -> Path:
    path = Path(raw or "/root")
    if not path.is_absolute():
        path = Path(STATE["cwd"]) / path
    return Path(os.path.realpath(path))


def list_dir(raw: str) -> dict:
    path = safe_path(raw)
    if not path.is_dir():
        return {"error": "not a directory", "path": str(path), "entries": []}
    entries = []
    try:
        names = sorted(path.iterdir(), key=lambda item: (not item.is_dir(), item.name.lower()))
    except OSError as exc:
        return {"error": str(exc), "path": str(path), "entries": []}
    for item in names:
        try:
            kind = "dir" if item.is_dir() else "link" if item.is_symlink() else "file"
            size = item.stat().st_size if kind != "dir" else 0
        except OSError:
            kind, size = "file", 0
        entries.append({"name": item.name, "kind": kind, "size": size})
    return {"path": str(path), "entries": entries}


def read_file(raw: str) -> dict:
    path = safe_path(raw)
    if not path.is_file():
        return {"error": "not a file", "path": str(path), "text": ""}
    data = path.read_bytes()[:200_000]
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        text = data.decode("utf-8", "replace")
    return {"path": str(path), "text": text, "size": path.stat().st_size}


def read_settings() -> dict:
    data = {"RESOLUTION": "", "UI_LANG": "ru", "KEYBOARD": "us,ru", "FONT_SIZE": "12"}
    if SETTINGS.exists():
        for line in SETTINGS.read_text(encoding="utf-8", errors="replace").splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                data[key] = value
    return data


def apply_settings(body: dict) -> dict:
    resolution = str(body.get("resolution") or "")
    lang = str(body.get("ui_lang") or "ru")
    keyboard = str(body.get("keyboard") or "us,ru")
    font = str(body.get("font_size") or "12")
    proc = run(f"/usr/bin/deepos-settings-apply save {resolution} {lang} {keyboard} {font}")
    status = Path("/tmp/deepos-settings.status").read_text(encoding="utf-8", errors="replace").strip() if Path("/tmp/deepos-settings.status").exists() else "OK"
    return {"status": status, "log": proc.stdout + proc.stderr}


def exec_cmd(cmd: str) -> dict:
    cmd = cmd.strip()
    cwd = STATE["cwd"]
    if cmd == "cd" or cmd.startswith("cd "):
        target = cmd[3:].strip() or "/root"
        path = safe_path(target if target.startswith("/") else str(Path(cwd) / target))
        if path.is_dir():
            STATE["cwd"] = str(path)
            return {"code": 0, "stdout": "", "stderr": "", "cwd": STATE["cwd"]}
        return {"code": 1, "stdout": "", "stderr": f"cd: {target}: нет такого каталога\n", "cwd": cwd}
    try:
        proc = run(cmd, cwd=cwd)
        code, out, err = proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired as exc:
        code, out, err = 124, exc.stdout or "", (exc.stderr or "") + "\nвремя ожидания истекло\n"
    return {"code": code, "stdout": out, "stderr": err, "cwd": STATE["cwd"]}


def create_entry(body: dict) -> dict:
    parent = safe_path(str(body.get("path") or "/root"))
    name = Path(str(body.get("name") or "")).name
    kind = body.get("kind") or "file"
    if not name or name in {".", ".."}:
        return {"error": "bad name"}
    dest = parent / name
    try:
        if kind == "dir":
            dest.mkdir(parents=False, exist_ok=False)
        else:
            dest.touch(exist_ok=False)
    except OSError as exc:
        return {"error": str(exc)}
    return {"ok": True, "path": str(dest)}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        return

    def send_json(self, payload: dict, status: int = 200) -> None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def send_file(self, path: Path) -> None:
        if not path.is_file():
            self.send_error(404)
            return
        data = path.read_bytes()
        kind = "text/html; charset=utf-8" if path.suffix == ".html" else "application/octet-stream"
        if path.suffix == ".js":
            kind = "text/javascript; charset=utf-8"
        if path.suffix == ".css":
            kind = "text/css; charset=utf-8"
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def body(self) -> dict:
        size = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(size) if size else b"{}"
        try:
            return json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            return {}

    def do_GET(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        if parsed.path == "/api/sysinfo":
            self.send_json(sysinfo())
            return
        if parsed.path == "/api/files":
            self.send_json(list_dir(query.get("path", ["/root"])[0]))
            return
        if parsed.path == "/api/read":
            self.send_json(read_file(query.get("path", [""])[0]))
            return
        if parsed.path == "/api/settings":
            self.send_json(read_settings())
            return
        rel = "index.html" if parsed.path in {"", "/"} else parsed.path.lstrip("/")
        target = (STATIC / rel).resolve()
        if STATIC.resolve() not in target.parents and target != STATIC.resolve():
            self.send_error(403)
            return
        self.send_file(target)

    def do_POST(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        payload = self.body()
        if parsed.path == "/api/exec":
            self.send_json(exec_cmd(str(payload.get("cmd") or "")))
            return
        if parsed.path == "/api/settings":
            self.send_json(apply_settings(payload))
            return
        if parsed.path == "/api/create":
            self.send_json(create_entry(payload))
            return
        if parsed.path == "/api/poweroff":
            self.send_json({"ok": True})
            threading.Timer(0.7, lambda: os.system("poweroff -f || reboot -f")).start()
            return
        self.send_error(404)


def main() -> None:
    os.makedirs("/root/.deepos", exist_ok=True)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
