#!/usr/bin/env python3
"""Launch the built DeepOS image in QEMU."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
KERNEL = ROOT / "out" / "vmlinuz"
INITRD = ROOT / "out" / "deepos-rootfs.cpio.gz"
STATE_BYTES = 8 * 1024 * 1024 * 1024


def find_qemu() -> Path | None:
    candidates: list[Path] = []
    for name in ("qemu-system-x86_64.exe", "qemu-system-x86_64"):
        found = shutil.which(name)
        if found:
            candidates.append(Path(found))
    candidates.extend(
        [
            ROOT / "tools" / "qemu" / "mingw64" / "bin" / "qemu-system-x86_64.exe",
            ROOT / "tools" / "qemu" / "qemu-system-x86_64.exe",
            Path(r"C:\Program Files\qemu\qemu-system-x86_64.exe"),
            Path(r"C:\Program Files\QEMU\qemu-system-x86_64.exe"),
        ]
    )
    for path in candidates:
        if path.is_file():
            return path
    return None


def stop_previous() -> None:
    if sys.platform != "win32":
        return
    script = (
        "Get-CimInstance Win32_Process -Filter \"Name = 'qemu-system-x86_64.exe'\" "
        "| Where-Object { $_.CommandLine -like '*deepos-rootfs.cpio.gz*' } "
        "| ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
    )
    subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
        check=False,
    )


def bios_dir(qemu: Path) -> Path | None:
    for candidate in (qemu.parent / "share", qemu.parent.parent / "share" / "qemu"):
        if (candidate / "bios-256k.bin").is_file():
            return candidate.resolve()
    return None


def guest_cpus() -> int:
    host = os.cpu_count() or 2
    return min(8, max(2, host // 2))


def grow_state(path: Path) -> None:
    """Keep the saved disk and extend it. The new tail stays unallocated."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        path.touch()
    if path.stat().st_size >= STATE_BYTES:
        return
    if sys.platform != "win32":
        with path.open("ab") as fh:
            fh.truncate(STATE_BYTES)
        return
    import ctypes
    from ctypes import wintypes

    kernel32 = ctypes.windll.kernel32
    handle = kernel32.CreateFileW(
        str(path),
        0x40000000,
        0x1 | 0x2,
        None,
        3,
        0x80,
        None,
    )
    if handle == wintypes.HANDLE(-1).value:
        with path.open("ab") as fh:
            fh.truncate(STATE_BYTES)
        return
    returned = wintypes.DWORD(0)
    kernel32.DeviceIoControl(handle, 0x900C4, None, 0, None, 0, ctypes.byref(returned), None)
    kernel32.SetFilePointerEx.argtypes = [
        wintypes.HANDLE,
        ctypes.c_longlong,
        ctypes.POINTER(ctypes.c_longlong),
        wintypes.DWORD,
    ]
    kernel32.SetFilePointerEx.restype = wintypes.BOOL
    kernel32.SetEndOfFile.argtypes = [wintypes.HANDLE]
    kernel32.SetEndOfFile.restype = wintypes.BOOL
    pos = ctypes.c_longlong()
    if kernel32.SetFilePointerEx(handle, STATE_BYTES, ctypes.byref(pos), 0):
        kernel32.SetEndOfFile(handle)
    kernel32.CloseHandle(handle)
    if path.stat().st_size < STATE_BYTES:
        with path.open("ab") as fh:
            fh.truncate(STATE_BYTES)


def main() -> int:
    if not KERNEL.is_file() or not INITRD.is_file():
        print("Image is missing. Run: python build.py")
        return 1

    qemu = find_qemu()
    if qemu is None:
        print("qemu-system-x86_64.exe was not found.")
        return 1

    stop_previous()

    serial_log = ROOT / "out" / "gui-serial.log"
    state = ROOT / "out" / "deepos-state.img"
    grow_state(state)
    smp = str(guest_cpus())
    args = [
        "-accel",
        "tcg,thread=multi",
        "-cpu",
        "qemu64",
        "-m",
        "6144",
        "-smp",
        smp,
        "-kernel",
        str(KERNEL),
        "-initrd",
        str(INITRD),
        "-append",
        "console=tty0 console=ttyS0,115200 rdinit=/init loglevel=3 noapic",
        "-netdev",
        "user,id=n0",
        "-device",
        "virtio-net-pci,netdev=n0",
        "-drive",
        f"file={state},if=virtio,format=raw",
        "-audiodev",
        "dsound,id=snd0",
        "-device",
        "intel-hda",
        "-device",
        "hda-duplex,audiodev=snd0",
        "-device",
        "virtio-vga,xres=1920,yres=1080",
        "-display",
        "gtk,gl=off,full-screen=off,grab-on-hover=off,zoom-to-fit=on,show-cursor=on,window-close=on",
        "-usb",
        "-device",
        "usb-tablet",
        "-name",
        "DeepOS",
        "-serial",
        f"file:{serial_log}",
        "-no-reboot",
    ]
    bios = bios_dir(qemu)
    if bios is not None:
        args = ["-L", str(bios), *args]

    print("Starting DeepOS desktop")
    print(f"QEMU: {qemu}")
    print("The graphical window is the DeepOS desktop. Close that window to power off.")
    completed = subprocess.run([str(qemu), *args], check=False)
    return completed.returncode


if __name__ == "__main__":
    sys.exit(main())
