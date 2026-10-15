#!/usr/bin/env python3
"""Boot DeepOS in QEMU and run a few commands on the serial console."""

from __future__ import annotations

import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QEMU = ROOT / "tools" / "qemu" / "qemu-system-x86_64.exe"
KERNEL = ROOT / "out" / "vmlinuz"
INITRD = ROOT / "out" / "deepos-rootfs.cpio.gz"
ERR = ROOT / "out" / "qemu.err"


def read_for(sock: socket.socket, seconds: float) -> bytes:
    sock.settimeout(0.4)
    end = time.time() + seconds
    data = b""
    while time.time() < end:
        try:
            chunk = sock.recv(8192)
            if not chunk:
                break
            data += chunk
            end = time.time() + 0.4
        except socket.timeout:
            if data:
                break
    return data


def main() -> int:
    err = ERR.open("wb")
    proc = subprocess.Popen(
        [
            str(QEMU),
            "-L",
            str(ROOT / "tools" / "qemu" / "share"),
            "-accel",
            "tcg,thread=single",
            "-m",
            "512",
            "-smp",
            "1",
            "-kernel",
            str(KERNEL),
            "-initrd",
            str(INITRD),
            "-append",
            "console=ttyS0,115200 rdinit=/init loglevel=4",
            "-display",
            "none",
            "-serial",
            "tcp:127.0.0.1:4445,server",
            "-netdev",
            "user,id=n0",
            "-device",
            "virtio-net-pci,netdev=n0",
            "-no-reboot",
        ],
        cwd=ROOT / "tools" / "qemu",
        stderr=err,
    )
    print(f"pid {proc.pid}", flush=True)
    sock = None
    for _ in range(50):
        if proc.poll() is not None:
            err.flush()
            print(ERR.read_text(encoding="utf-8", errors="replace"))
            return 1
        try:
            sock = socket.create_connection(("127.0.0.1", 4445), timeout=2)
            break
        except OSError:
            time.sleep(0.2)
    if sock is None:
        print("serial port was not opened")
        proc.kill()
        return 1

    buf = b""
    deadline = time.time() + 60
    sock.settimeout(1)
    while time.time() < deadline:
        try:
            chunk = sock.recv(8192)
            if not chunk:
                break
            buf += chunk
            if b"deepos:" in buf and b"Kernel panic" not in buf and buf.rstrip().endswith(b"#"):
                break
        except socket.timeout:
            if b"deepos:" in buf and b"Kernel panic" not in buf:
                break
    text = buf.decode("utf-8", "replace")
    print("---BOOT---")
    print(text)
    if b"Kernel panic" in buf or b"deepos:" not in buf:
        proc.kill()
        return 1

    for cmd in ("uname -a", "cat /etc/os-release", "mount", "deepos-info"):
        sock.sendall((cmd + "\n").encode())
        part = read_for(sock, 3)
        print(f"---CMD {cmd} ---")
        print(part.decode("utf-8", "replace"))
    print("alive", proc.poll() is None)
    (ROOT / "out" / "qemu.pid").write_text(str(proc.pid), encoding="ascii")
    return 0 if proc.poll() is None else 1


if __name__ == "__main__":
    sys.exit(main())
