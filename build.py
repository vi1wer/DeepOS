#!/usr/bin/env python3
"""Build DeepOS: Linux kernel + userspace packed as an initramfs."""

from __future__ import annotations

import gzip
import re
import io
import json
import os
import shutil
import stat
import sys
import tarfile
import time
import urllib.request
import zlib
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CACHE = ROOT / "cache"
APK_CACHE = CACHE / "apk"
OUT = ROOT / "out"

ALPINE_BRANCH_URL = "https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/x86_64/APKINDEX.tar.gz"
REPOS = ("main", "community")

ROOT_PACKAGES = [
    "busybox",
    "alpine-baselayout",
    "alpine-baselayout-data",
    "musl",
    "apk-tools",
    "alpine-keys",
    "ca-certificates",
    "ca-certificates-bundle",
    "linux-virt",
    "bash",
    "coreutils",
    "util-linux",
    "procps-ng",
    "procps",
    "iproute2",
    "curl",
    "kmod",
    "e2fsprogs",
    "e2fsprogs-extra",
    "nano",
    "less",
    "openssh-client",
    "iputils",
    "xorg-server",
    "xf86-input-evdev",
    "xinit",
    "xset",
    "xsetroot",
    "xterm",
    "xclock",
    "jwm",
    "font-dejavu",
    "fontconfig",
    "setxkbmap",
    "mc",
    "tk",
    "xrandr",
    "netsurf",
    "firefox",
    "chromium",
    "xdotool",
    "xprop",
    "alsa-utils",
    "scrot",
    "espeak-ng",
    "tzdata",
    "wine",
]

SKIP_PACKAGES = {
    "linux-firmware",
    "linux-firmware-any",
    "linux-firmware-none",
    "linux-firmware-other",
    "linux-firmware-mediatek",
    "linux-firmware-nvidia",
    "linux-firmware-amd",
    "linux-firmware-intel",
}

USER_AGENT = "DeepOS-builder/1.0"


def log(msg: str) -> None:
    print(msg, flush=True)


def next_build_version() -> str:
    """Stamp YYYY.MM.DD-build.N. N counts builds on the local day, then resets."""
    OUT.mkdir(parents=True, exist_ok=True)
    day = datetime.now().strftime("%Y.%m.%d")
    path = OUT / "build-seq.json"
    n = 1
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if data.get("date") == day:
                n = int(data.get("n") or 0) + 1
        except (OSError, ValueError, TypeError):
            n = 1
    version = f"{day}-build.{n}"
    path.write_text(json.dumps({"date": day, "n": n}, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "VERSION").write_text(f"DeepOS {version}\n", encoding="utf-8")
    stamp_site(day)
    return version


def stamp_site(day: str) -> None:
    """Put the build day into the public site. News dates stay as written."""
    pat = re.compile(r'(<span class="deepos-day">)[^<]*(</span>)')
    site = ROOT / "site"
    if not site.is_dir():
        return
    for path in site.glob("*.html"):
        text = path.read_text(encoding="utf-8")
        new, count = pat.subn(rf"\g<1>{day}\2", text)
        if count and new != text:
            path.write_text(new, encoding="utf-8", newline="\n")


def ver_key(version: str) -> list:
    parts: list = []
    token = ""
    for ch in version:
        if ch.isdigit():
            token += ch
            continue
        if token:
            parts.append(int(token))
            token = ""
        parts.append(ch)
    if token:
        parts.append(int(token))
    return parts


def download(url: str, dest: Path, expected: int | None = None) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 0:
        if not expected or dest.stat().st_size == expected:
            return dest
        log(f"  drop short cache {dest.name}: {dest.stat().st_size} != {expected}")
        dest.unlink()
    tmp = dest.with_suffix(dest.suffix + ".part")
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_err: Exception | None = None
    for attempt in range(4):
        try:
            log(f"  download {url}")
            with urllib.request.urlopen(req, timeout=180) as resp, tmp.open("wb") as out:
                shutil.copyfileobj(resp, out)
                length = resp.headers.get("Content-Length")
            size = tmp.stat().st_size
            if length and size != int(length):
                raise OSError(f"short download {size} != {length}")
            if expected and size != expected:
                raise OSError(f"short download {size} != {expected}")
            tmp.replace(dest)
            return dest
        except Exception as exc:  # noqa: BLE001 - retry network errors
            last_err = exc
            log(f"  retry {attempt + 1}: {exc}")
            time.sleep(2 + attempt * 2)
            if tmp.exists():
                tmp.unlink()
    raise RuntimeError(f"failed to download {url}: {last_err}")


def parse_apkindex(text: str, repo: str, repo_base: str) -> list[dict]:
    packages: list[dict] = []
    current: dict[str, str] = {}
    for line in text.splitlines():
        if not line:
            if current.get("P"):
                current["repo"] = repo
                current["repo_base"] = repo_base
                packages.append(current)
            current = {}
            continue
        if len(line) >= 2 and line[1] == ":":
            key, value = line[0], line[2:]
            if key in current and key in {"D", "p"}:
                current[key] += " " + value
            else:
                current[key] = value
    if current.get("P"):
        current["repo"] = repo
        current["repo_base"] = repo_base
        packages.append(current)
    return packages


def load_indexes(branch_root: str) -> tuple[dict[str, dict], dict[str, list[dict]]]:
    by_name: dict[str, dict] = {}
    all_pkgs: list[dict] = []
    for repo in REPOS:
        repo_base = f"{branch_root}/{repo}/x86_64"
        url = f"{repo_base}/APKINDEX.tar.gz"
        dest = CACHE / f"APKINDEX-{repo}.tar.gz"
        download(url, dest)
        with tarfile.open(dest, "r:gz") as tar:
            member = tar.getmember("APKINDEX")
            text = tar.extractfile(member).read().decode("utf-8", "replace")
        all_pkgs.extend(parse_apkindex(text, repo, repo_base))

    for pkg in all_pkgs:
        name = pkg["P"]
        prev = by_name.get(name)
        if prev is None or ver_key(pkg["V"]) > ver_key(prev["V"]):
            by_name[name] = pkg

    providers: dict[str, list[dict]] = {}
    for pkg in by_name.values():
        names = {pkg["P"]}
        for item in pkg.get("p", "").split():
            names.add(item.split("=")[0])
        for name in names:
            providers.setdefault(name, []).append(pkg)
    return by_name, providers


def dep_names(pkg: dict) -> list[str]:
    result = []
    for item in pkg.get("D", "").split():
        if item.startswith("!"):
            continue
        name = item
        for sep in ("=", ">", "<", "~"):
            name = name.split(sep)[0]
        if name:
            result.append(name)
    return result


def resolve(by_name: dict[str, dict], providers: dict[str, list[dict]], roots: list[str]) -> list[dict]:
    selected: list[dict] = []
    seen: set[str] = set()
    missing: list[str] = []

    def find(name: str) -> dict | None:
        if name in by_name:
            return by_name[name]
        cands = providers.get(name) or []
        if not cands:
            return None
        return min(cands, key=lambda pkg: int(pkg.get("I") or 10**12))

    def visit(name: str) -> None:
        pkg = find(name)
        if pkg is None:
            missing.append(name)
            return
        real = pkg["P"]
        if real in SKIP_PACKAGES:
            return
        if real in seen:
            return
        seen.add(real)
        for dep in dep_names(pkg):
            visit(dep)
        selected.append(pkg)

    for root in roots:
        visit(root)
    if missing:
        unique = sorted(set(missing))
        log("warning: unresolved dependencies: " + ", ".join(unique[:40]))
    return selected


def gzip_payloads(blob: bytes) -> list[bytes]:
    pos = blob.find(b"\x1f\x8b")
    payloads: list[bytes] = []
    while pos != -1 and pos < len(blob):
        decompressor = zlib.decompressobj(16 + zlib.MAX_WBITS)
        try:
            payload = decompressor.decompress(blob[pos:]) + decompressor.flush()
        except zlib.error:
            pos = blob.find(b"\x1f\x8b", pos + 2)
            continue
        payloads.append(payload)
        unused = decompressor.unused_data
        if not unused:
            break
        end = len(blob) - len(unused)
        rel = unused.find(b"\x1f\x8b")
        if rel < 0:
            break
        pos = end + rel
    return payloads


def norm_path(name: str) -> str:
    name = name.replace("\\", "/").lstrip("/")
    while name.startswith("./"):
        name = name[2:]
    return name


class FsNode:
    __slots__ = ("kind", "mode", "data", "rmajor", "rminor")

    def __init__(self, kind: str, mode: int, data: bytes = b"", rmajor: int = 0, rminor: int = 0):
        self.kind = kind
        self.mode = mode
        self.data = data
        self.rmajor = rmajor
        self.rminor = rminor


def add_node(tree: dict[str, FsNode], path: str, node: FsNode) -> None:
    path = norm_path(path)
    if path in ("", "."):
        return
    tree[path] = node
    parent = path.rsplit("/", 1)[0] if "/" in path else ""
    while parent:
        if parent not in tree:
            tree[parent] = FsNode("dir", 0o040755)
        if "/" not in parent:
            break
        parent = parent.rsplit("/", 1)[0]


def ingest_tar(tree: dict[str, FsNode], payload: bytes, kernel_out: list[bytes]) -> None:
    try:
        tar = tarfile.open(fileobj=io.BytesIO(payload), mode="r:")
    except tarfile.TarError:
        return
    contents: dict[str, bytes] = {}
    members = [m for m in tar.getmembers() if m.name]
    for member in members:
        path = norm_path(member.name)
        if not path or path.startswith(".SIGN") or path in {".PKGINFO"}:
            continue
        if member.isreg():
            extracted = tar.extractfile(member)
            contents[path] = extracted.read() if extracted else b""
    for member in members:
        path = norm_path(member.name)
        if not path or path.startswith(".SIGN") or path in {".PKGINFO"}:
            continue
        mode = member.mode & 0o7777
        if member.issym():
            add_node(tree, path, FsNode("lnk", 0o120000 | (mode or 0o777), member.linkname.encode()))
        elif member.isdir():
            add_node(tree, path, FsNode("dir", 0o040000 | (mode or 0o755)))
        elif member.ischr():
            add_node(tree, path, FsNode("chr", 0o020000 | mode, rmajor=member.devmajor or 0, rminor=member.devminor or 0))
        elif member.isblk():
            add_node(tree, path, FsNode("blk", 0o060000 | mode, rmajor=member.devmajor or 0, rminor=member.devminor or 0))
        elif member.isfifo():
            add_node(tree, path, FsNode("fifo", 0o010000 | mode))
        elif member.islnk() or member.isreg():
            if member.islnk():
                data = contents.get(norm_path(member.linkname), b"")
            else:
                data = contents.get(path, b"")
            base = path.rsplit("/", 1)[-1]
            if path.startswith("boot/vmlinuz") or base.startswith("vmlinuz"):
                kernel_out.clear()
                kernel_out.append(data)
                continue
            add_node(tree, path, FsNode("reg", 0o100000 | (mode or 0o644), data))


def overlay_text(tree: dict[str, FsNode], path: str, text: str, executable: bool = False) -> None:
    data = text.replace("\r\n", "\n").encode("utf-8")
    mode = 0o100755 if executable else 0o100644
    add_node(tree, path, FsNode("reg", mode, data))


def jwm_config(terminal: str, files: str, settings: str, about: str, restart: str, leave: str) -> str:
    return f"""<?xml version="1.0"?>
<JWM>
  <RootMenu onroot="3">
    <Program label="{terminal}">deepos-term</Program>
    <Program label="{files}">deepos-term -e mc</Program>
    <Program label="{settings}">deepos-settings</Program>
    <Program label="{about}">deepos-term -e deepos-info</Program>
    <Separator/>
    <Restart label="{restart}"/>
    <Exit label="{leave}"/>
  </RootMenu>
  <Desktops width="1" height="1">
    <Background type="solid">#1c1b19</Background>
  </Desktops>
  <Tray x="0" y="0" height="36" autohide="off">
    <TrayButton label="DeepOS">root:1</TrayButton>
    <TaskList maxwidth="240"/>
    <Dock/>
    <Clock format="%H:%M">deepos-term</Clock>
  </Tray>
  <WindowStyle>
    <Font>DejaVu Sans-11</Font>
    <Width>3</Width>
    <Height>28</Height>
    <Active>
      <Text>#e7b48a</Text>
      <Title>#312e2b</Title>
      <Outline>#c4a484</Outline>
    </Active>
    <Inactive>
      <Text>#b3aa9e</Text>
      <Title>#262421</Title>
      <Outline>#312e2b</Outline>
    </Inactive>
  </WindowStyle>
  <TrayStyle>
    <Font>DejaVu Sans-11</Font>
    <Foreground>#f6f1ea</Foreground>
    <Background>#262421</Background>
    <Outline>#312e2b</Outline>
    <Active>
      <Foreground>#e7b48a</Foreground>
      <Background>#312e2b</Background>
    </Active>
  </TrayStyle>
  <TaskListStyle>
    <Font>DejaVu Sans-11</Font>
    <Foreground>#b3aa9e</Foreground>
    <Background>#262421</Background>
    <Active>
      <Foreground>#e7b48a</Foreground>
      <Background>#312e2b</Background>
    </Active>
  </TaskListStyle>
  <MenuStyle>
    <Font>DejaVu Sans-11</Font>
    <Foreground>#f6f1ea</Foreground>
    <Background>#262421</Background>
    <Outline>#312e2b</Outline>
    <Active>
      <Foreground>#e7b48a</Foreground>
      <Background>#312e2b</Background>
    </Active>
  </MenuStyle>
  <PopupStyle>
    <Font>DejaVu Sans-11</Font>
    <Foreground>#1c1b19</Foreground>
    <Background>#e7b48a</Background>
    <Outline>#c4a484</Outline>
  </PopupStyle>
  <Key key="A+t">exec:deepos-term</Key>
  <Key key="A+s">exec:deepos-settings</Key>
  <StartupCommand>deepos-welcome</StartupCommand>
</JWM>
"""


def apply_overlay(tree: dict[str, FsNode], branch: str, version: str) -> None:
    overlay_text(
        tree,
        "init",
        """#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export HOME=/root
export TERM=vt100

if [ -x /bin/busybox ]; then
    /bin/busybox --install -s /bin
fi

mkdir -p /proc /sys /dev /tmp /run /root /var/log /etc
mount -t proc proc /proc
mount -t sysfs sysfs /sys
if ! mount -t devtmpfs devtmpfs /dev 2>/dev/null; then
    mount -t tmpfs tmpfs /dev
    mdev -s 2>/dev/null
fi
mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts 2>/dev/null
mount -t tmpfs tmpfs /tmp
mount -t tmpfs tmpfs /run
ln -sf /proc/mounts /etc/mtab 2>/dev/null

if [ -f /etc/hostname ]; then
    hostname -F /etc/hostname 2>/dev/null || hostname deepos
else
    hostname deepos
fi

mkdir -p /tmp/.X11-unix /var/log /var/cache/fontconfig /root
chmod 1777 /tmp /tmp/.X11-unix

KMOD=""
for candidate in /bin/kmod /usr/bin/kmod /sbin/kmod; do
    if [ -x "$candidate" ]; then
        KMOD=$candidate
        break
    fi
done
if [ -n "$KMOD" ]; then
    "$KMOD" depmod -a >/var/log/modprobe.log 2>&1
    for module in virtio_pci virtio_net virtio-net evdev mousedev psmouse uhci-hcd ehci-pci usbhid hid-generic virtio-gpu virtio_gpu; do
        "$KMOD" modprobe "$module" >>/var/log/modprobe.log 2>&1
    done
    for module in virtio_blk virtio-blk ext4 crc32c snd_hda_intel snd-hda-intel; do
        "$KMOD" modprobe "$module" >>/var/log/modprobe.log 2>&1
    done
fi

load_ko() {
    src=$1
    base=$(basename "$src" .gz)
    dst=/tmp/$base
    if [ ! -f "$src" ]; then
        echo "DEEPOS_NOMOD $src" > /dev/ttyS0
        return
    fi
    gzip -dc "$src" > "$dst" 2>/tmp/gunzip.err
    if [ -n "$KMOD" ]; then
        "$KMOD" insmod "$dst" >/tmp/insmod.err 2>&1
    else
        insmod "$dst" >/tmp/insmod.err 2>&1
    fi
    rc=$?
    echo "DEEPOS_INSMOD $base $rc $(tr '\n' ' ' < /tmp/insmod.err)" > /dev/ttyS0
}
MODDIR=/lib/modules/$(uname -r)
load_ko "$MODDIR/kernel/net/core/failover.ko.gz"
load_ko "$MODDIR/kernel/drivers/net/net_failover.ko.gz"
load_ko "$MODDIR/kernel/drivers/net/virtio_net.ko.gz"
echo "DEEPOS_LINKS $(ls /sys/class/net 2>/dev/null | tr '\n' ' ')" > /dev/ttyS0

if [ -x /sbin/udevd ]; then
    /sbin/udevd --daemon >>/var/log/udev.log 2>&1
    udevadm trigger --action=add >>/var/log/udev.log 2>&1
    udevadm settle --timeout=4 >>/var/log/udev.log 2>&1
fi

ip link set lo up 2>/dev/null
printf '%s\n' "nameserver 1.1.1.1" "nameserver 8.8.8.8" "nameserver 77.88.8.8" "nameserver 10.0.2.3" > /etc/resolv.conf
iface=""
for cand in /sys/class/net/*; do
    name=${cand##*/}
    if [ "$name" != "lo" ] && [ "$name" != "*" ]; then
        iface=$name
        break
    fi
done
if [ -n "$iface" ]; then
    ip link set "$iface" up 2>/dev/null
    udhcpc -i "$iface" -s /etc/udhcpc.script -t 5 -T 1 -n -q >/var/log/udhcpc.log 2>&1
    if ! ip route show default 2>/dev/null | grep -q .; then
        ip addr add 10.0.2.15/24 dev "$iface" 2>/dev/null
        ip route add default via 10.0.2.2 dev "$iface" 2>/dev/null
    fi
    echo "DEEPOS_NET $iface $(ip -4 -o addr show dev "$iface" 2>/dev/null) $(ip route show default 2>/dev/null)" > /dev/ttyS0
    curl -4 -sS -m 12 --dns-servers 1.1.1.1,8.8.8.8 -o /dev/null -w "DEEPOS_HTTP %{http_code}\n" https://example.com/ > /dev/ttyS0 2>/tmp/curlerr
    echo "DEEPOS_CURL $(tr '\n' ' ' < /tmp/curlerr)" > /dev/ttyS0
else
    echo "DEEPOS_NET none" > /dev/ttyS0
fi

load_ko "$MODDIR/kernel/fs/mbcache.ko.gz"
load_ko "$MODDIR/kernel/fs/jbd2/jbd2.ko.gz"
load_ko "$MODDIR/kernel/fs/ext4/ext4.ko.gz"
if [ -x /usr/bin/deepos-persist ]; then
    /usr/bin/deepos-persist >/var/log/persist.log 2>&1
fi

if [ -x /usr/bin/xinit ] && [ -x /usr/bin/deepos-session ]; then
    echo "Запуск рабочего стола DeepOS..." > /dev/tty0 2>/dev/null
    echo "DEEPOS_GUI_START" > /dev/ttyS0 2>/dev/null
    fails=0
    while [ "$fails" -lt 2 ]; do
        xinit /usr/bin/deepos-session -- :0 vt1 -nolisten tcp -noreset >/var/log/xinit.log 2>&1
        status=$?
        echo "DEEPOS_GUI_EXIT $status" > /dev/ttyS0 2>/dev/null
        if [ -f /var/log/Xorg.0.log ]; then
            tail -n 50 /var/log/Xorg.0.log > /dev/ttyS0 2>/dev/null
        fi
        fails=$((fails + 1))
        sleep 2
    done
fi

echo
echo "Графический сеанс остановлен. Текстовая оболочка:"
cat /etc/motd
exec /bin/sh -l </dev/console >/dev/console 2>&1
""",
        executable=True,
    )
    overlay_text(
        tree,
        "etc/os-release",
        f"""NAME="DeepOS"
VERSION="{version}"
ID=deepos
ID_LIKE=alpine
PRETTY_NAME="DeepOS {version}"
VERSION_ID={version}
HOME_URL="https://deepos.local"
BUILD_BRANCH={branch}
""",
    )
    overlay_text(
        tree,
        "etc/hostname",
        "deepos\n",
    )
    overlay_text(
        tree,
        "root/.netsurf/Choices",
        """bar_show:none
homepage_url:about:blank
animate_images:1
""",
    )
    overlay_text(
        tree,
        "root/.config/netsurf/Choices",
        """bar_show:none
homepage_url:about:blank
animate_images:1
""",
    )
    overlay_text(
        tree,
        "etc/issue",
        f"DeepOS {version} (Linux) \\n \\l\n",
    )
    overlay_text(
        tree,
        "etc/motd",
        f"""========================================
  DeepOS {version}
  Independent Operating System
========================================

  Меню: кнопка DeepOS или правая кнопка мыши.
  Настройки: разрешение, язык, клавиатура.
  Alt+T терминал, Alt+S настройки, Alt+Shift раскладка.

========================================
""",
    )
    overlay_text(
        tree,
        "etc/profile",
        f"""export PATH=/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export TERM=${{TERM:-vt100}}
echo "DeepOS {version}"
PS1="$(printf '\\033[36m')DeepOS {version}$(printf '\\033[0m:')\\w$(printf '\\033[92m# \\033[0m')"
export PS1
alias ll='ls -la'
""",
    )
    overlay_text(
        tree,
        "etc/apk/repositories",
        f"""https://dl-cdn.alpinelinux.org/alpine/{branch}/main
https://dl-cdn.alpinelinux.org/alpine/{branch}/community
""",
    )
    overlay_text(tree, "etc/apk/world", "\n")
    overlay_text(tree, "etc/apk/arch", "x86_64\n")
    overlay_text(
        tree,
        "etc/udhcpc.script",
        """#!/bin/sh
bits=24
case "$subnet" in
    255.255.255.0) bits=24 ;;
    255.255.0.0) bits=16 ;;
    255.0.0.0) bits=8 ;;
esac
case "$1" in
    bound|renew)
        ip link set "$interface" up
        ip addr flush dev "$interface" 2>/dev/null
        ip addr add "$ip/$bits" dev "$interface"
        if [ -n "$router" ]; then
            ip route replace default via "${router%% *}" dev "$interface"
        fi
        {
            echo "nameserver 1.1.1.1"
            echo "nameserver 8.8.8.8"
            echo "nameserver 77.88.8.8"
            if [ -n "$dns" ]; then
                for server in $dns; do
                    echo "nameserver $server"
                done
            fi
        } > /etc/resolv.conf
        ;;
esac
exit 0
""",
        executable=True,
    )
    overlay_text(
        tree,
        "usr/bin/deepos-info",
        f"""#!/bin/sh
if [ -f /etc/os-release ]; then
    . /etc/os-release
fi
echo "${{PRETTY_NAME:-DeepOS {version}}}"
echo "----------------"
echo "${{VERSION:-{version}}}"
uname -a
echo
echo "Память:"
grep -E 'MemTotal|MemAvailable|MemFree' /proc/meminfo
echo
echo "Сеть:"
ip addr 2>/dev/null || ifconfig -a
echo
echo "Файловые системы:"
mount
""",
        executable=True,
    )
    jwm_ru = jwm_config("Терминал", "Файлы", "Настройки", "О системе", "Перезапуск", "Выход на консоль")
    jwm_en = jwm_config("Terminal", "Files", "Settings", "About", "Restart", "Exit to console")
    overlay_text(tree, "usr/share/deepos/jwm-ru.jwmrc", jwm_ru)
    overlay_text(tree, "usr/share/deepos/jwm-en.jwmrc", jwm_en)
    overlay_text(tree, "etc/jwm/system.jwmrc", jwm_ru)
    overlay_text(tree, "root/.jwmrc", jwm_ru)
    overlay_text(
        tree,
        "etc/X11/Xwrapper.config",
        """allowed_users=anybody
needs_root_rights=yes
""",
    )
    overlay_text(
        tree,
        "etc/X11/xorg.conf",
        """Section "Device"
    Identifier "DeepOS"
    Driver "modesetting"
EndSection
Section "ServerFlags"
    Option "AutoAddDevices" "true"
    Option "DontVTSwitch" "false"
    Option "AllowMouseOpenFail" "true"
EndSection
Section "Extensions"
    Option "Composite" "Enable"
EndSection
""",
    )
    overlay_text(
        tree,
        "usr/bin/deepos-persist",
        r"""#!/bin/sh
modprobe virtio_blk 2>/dev/null
modprobe virtio-blk 2>/dev/null
modprobe ext4 2>/dev/null
modprobe crc32c 2>/dev/null
modprobe crc32c_intel 2>/dev/null
i=0
while [ ! -b /dev/vda ] && [ "$i" -lt 30 ]; do
    sleep 0.1
    i=$((i + 1))
done
if [ ! -b /dev/vda ]; then
    echo "DEEPOS_PERSIST nodisk" > /dev/ttyS0
    exit 0
fi
mkdir -p /persist
if ! blkid /dev/vda >/dev/null 2>&1; then
    mkfs.ext4 -F -L deepos-state /dev/vda >>/var/log/persist.log 2>&1 || {
        echo "DEEPOS_PERSIST mkfs" > /dev/ttyS0
        exit 0
    }
fi
if ! mount -t ext4 -o noatime,commit=1 /dev/vda /persist >>/var/log/persist.log 2>&1; then
    mkfs.ext4 -F -L deepos-state -O ^orphan_file /dev/vda >>/var/log/persist.log 2>&1
    if ! mount -t ext4 -o noatime,commit=1 /dev/vda /persist >>/var/log/persist.log 2>&1; then
        echo "DEEPOS_PERSIST mount $(blockdev --getsize64 /dev/vda 2>/dev/null) $(tail -n 2 /var/log/persist.log | tr '\n' ' ') $(dmesg | tail -n 4 | tr '\n' ' ')" > /dev/ttyS0
        exit 0
    fi
fi
disk=$(blockdev --getsize64 /dev/vda 2>/dev/null || echo 0)
echo "DEEPOS_DISK $disk" > /dev/ttyS0
umount /persist >>/var/log/persist.log 2>&1 || true
e2fsck -f -p /dev/vda >>/var/log/persist.log 2>&1 || true
resize2fs /dev/vda >>/var/log/persist.log 2>&1 || true
if ! mount -t ext4 -o noatime,commit=1 /dev/vda /persist >>/var/log/persist.log 2>&1; then
    echo "DEEPOS_PERSIST remount $(tail -n 2 /var/log/persist.log | tr '\n' ' ')" > /dev/ttyS0
    exit 0
fi
echo "DEEPOS_RESIZE $(df -P /persist | awk 'NR==2 {print $2}') $(tail -n 1 /var/log/persist.log | tr '\n' ' ')" > /dev/ttyS0
mkdir -p /persist/home /persist/apk /root
if [ -d /persist/deepos ] && [ ! -e /persist/home/.deepos ]; then
    cp -a /persist/deepos /persist/home/.deepos
fi
if [ -d /persist/desktop ] && [ ! -e /persist/home/Desktop ]; then
    cp -a /persist/desktop /persist/home/Desktop
fi
if [ -d /persist/trash ] && [ ! -e /persist/home/.Trash ]; then
    cp -a /persist/trash /persist/home/.Trash
fi
if [ -d /persist/config ] && [ ! -e /persist/home/.config/deepos ]; then
    mkdir -p /persist/home/.config
    cp -a /persist/config /persist/home/.config/deepos
fi
merge_home() {
    src=$1
    dst=$2
    mkdir -p "$dst"
    for child in "$src"/* "$src"/.[!.]* "$src"/..?*; do
        [ -e "$child" ] || [ -L "$child" ] || continue
        name=${child##*/}
        if [ -L "$child" ]; then
            continue
        fi
        if [ -d "$child" ]; then
            merge_home "$child" "$dst/$name"
        elif [ ! -e "$dst/$name" ]; then
            cp -a "$child" "$dst/$name"
        fi
    done
}
merge_home /root /persist/home
if mount --bind /persist/home /root >>/var/log/persist.log 2>&1; then
    echo "DEEPOS_PERSIST home $(df -P /root | awk 'NR==2 {print $2,$4}')" > /dev/ttyS0
else
    echo "DEEPOS_PERSIST home" > /dev/ttyS0
    mkdir -p /persist/deepos /persist/desktop /persist/trash /persist/config
    if [ ! -L /root/.deepos ]; then
        mkdir -p /root/.deepos
        cp -a /root/.deepos/. /persist/deepos/ 2>/dev/null
        rm -rf /root/.deepos
        ln -s /persist/deepos /root/.deepos
    fi
    if [ ! -L /root/Desktop ]; then
        if [ -d /root/Desktop ]; then
            cp -a /root/Desktop/. /persist/desktop/ 2>/dev/null
            rm -rf /root/Desktop
        fi
        ln -s /persist/desktop /root/Desktop
    fi
    if [ ! -L /root/.Trash ]; then
        rm -rf /root/.Trash
        ln -s /persist/trash /root/.Trash
    fi
    mkdir -p /root/.config
    if [ ! -L /root/.config/deepos ]; then
        if [ -d /root/.config/deepos ]; then
            cp -a /root/.config/deepos/. /persist/config/ 2>/dev/null
            rm -rf /root/.config/deepos
        fi
        ln -s /persist/config /root/.config/deepos
    fi
fi
mkdir -p /root/.deepos
if [ ! -f /root/.deepos/settings ] && [ -f /etc/deepos/settings ]; then
    cp /etc/deepos/settings /root/.deepos/settings
fi
if [ ! -L /var/cache/apk ]; then
    mkdir -p /persist/apk /var/cache
    rm -rf /var/cache/apk
    ln -s /persist/apk /var/cache/apk
fi
echo "DEEPOS_PERSIST ok" > /dev/ttyS0
(
    list=""
    if [ -s /root/.deepos/world ]; then
        list="$list $(cat /root/.deepos/world)"
    fi
    for w in /persist/accounts/*/home/.deepos/world; do
        if [ -s "$w" ]; then
            list="$list $(cat "$w")"
        fi
    done
    if [ -n "$(echo $list)" ]; then
        apk add --no-progress $list >>/var/log/apk-replay.log 2>&1
    fi
    echo "DEEPOS_PKGS done" > /dev/ttyS0
) &
exit 0
""",
        executable=True,
    )
    overlay_text(
        tree,
        "usr/bin/deepos-exe",
        """#!/bin/sh
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all
export WINEDLLOVERRIDES=winemenubuilder.exe=d
if [ ! -x /usr/bin/wine ]; then
    echo "EXE runtime is missing" >&2
    exit 1
fi
if [ ! -d "$WINEPREFIX/drive_c" ]; then
    wineboot -i >/tmp/deepos-wineboot.log 2>&1 || wineboot --init >/tmp/deepos-wineboot.log 2>&1
fi
exec wine "$@"
""",
        executable=True,
    )
    overlay_text(
        tree,
        "usr/bin/deepos-pkg",
        r"""#!/bin/sh
world=/root/.deepos/world
mkdir -p /root/.deepos
cmd=$1
name=$2
mkdir -p /lib/apk/db /etc/apk /var/cache/apk
if [ ! -s /etc/apk/world ]; then
    printf '\n' > /etc/apk/world
fi
if [ ! -s /etc/apk/arch ]; then
    printf 'x86_64\n' > /etc/apk/arch
fi
case "$cmd" in
    update)
        apk update
        ;;
    search)
        apk search -q "$name" | head -n 80
        ;;
    installed)
        if [ -f "$world" ]; then
            sort -u "$world"
        fi
        ;;
    add)
        if command -v stdbuf >/dev/null 2>&1; then
            stdbuf -oL -eL apk add --no-progress "$name" || exit 1
        else
            apk add --no-progress "$name" || exit 1
        fi
        touch "$world"
        grep -qx "$name" "$world" || echo "$name" >> "$world"
        ;;
    del)
        apk del "$name" || exit 1
        if [ -f "$world" ]; then
            grep -vx "$name" "$world" > "$world.tmp" && mv "$world.tmp" "$world"
        fi
        ;;
    plan)
        apk upgrade -s
        ;;
    upgrade)
        apk upgrade --no-progress
        ;;
    info)
        apk info -d -s "$name"
        ;;
    *)
        echo "usage: deepos-pkg update|search|installed|add|del|plan|upgrade|info" >&2
        exit 1
        ;;
esac
""",
        executable=True,
    )
    overlay_text(
        tree,
        "usr/bin/deepos-session",
        """#!/bin/sh
export DISPLAY=:0
export HOME=/root
export LANG=C.UTF-8
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
export TZ=Europe/Samara
cd /
rm -f /persist/accounts/mounted
mkdir -p /root/.deepos /tmp /var/log
if [ -f /root/.deepos/settings ]; then
    # shellcheck disable=SC1091
    . /root/.deepos/settings
fi
export TZ
export GDK_BACKEND=x11
export SDL_VIDEODRIVER=x11
export vblank_mode=0
if [ -f "/usr/share/zoneinfo/$TZ" ]; then
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
fi
echo "DEEPOS_DATE $(date '+%H:%M %Z') TZ=$TZ" >/dev/ttyS0
echo "DEEPOS_CPU $(nproc 2>/dev/null)" >/dev/ttyS0
if [ -d /dev/dri ]; then
    echo "DEEPOS_GPU $(ls /dev/dri | tr '\n' ' ')" >/dev/ttyS0
else
    echo "DEEPOS_GPU none" >/dev/ttyS0
fi
(while true; do sync; sleep 8; done) >/dev/null 2>&1 &
deepos-settings-apply boot >/var/log/deepos-settings.log 2>&1
fc-cache -f /usr/share/fonts >/var/log/fc-cache.log 2>&1
if [ -x /usr/bin/xcompmgr ]; then
    xcompmgr >/var/log/xcompmgr.log 2>&1 &
    sleep 0.3
    if pidof xcompmgr >/dev/null 2>&1; then
        echo DEEPOS_XCOMP ok >/dev/ttyS0
    else
        echo "DEEPOS_XCOMP fail $(tr '\n' ' ' < /var/log/xcompmgr.log)" >/dev/ttyS0
    fi
fi
xsetroot -solid "#0c0b0a" 2>/dev/null
xsetroot -cursor_name left_ptr 2>/dev/null
deepos-wmhint >/var/log/deepos-wmhint.log 2>&1
wish /usr/share/deepos/desktop.tcl >/var/log/desktop.log 2>&1
status=$?
echo "DEEPOS_WISH $status" >/dev/ttyS0
cat /var/log/desktop.log >/dev/ttyS0
exit $status
""",
        executable=True,
    )
    overlay_text(
        tree,
        "usr/bin/deepos-wmhint",
        r"""#!/bin/sh
export DISPLAY=${DISPLAY:-:0}
if [ -f /tmp/deepos-wmhint.pid ]; then
    pid=$(cat /tmp/deepos-wmhint.pid 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        exit 0
    fi
fi
wish /usr/share/deepos/wmhint.tcl >/var/log/deepos-wmhint.log 2>&1 &
echo $! > /tmp/deepos-wmhint.pid
""",
        executable=True,
    )
    overlay_text(
        tree,
        "usr/share/deepos/wmhint.tcl",
        r"""#!/usr/bin/wish
# Advertise Openbox over EWMH so Chromium enables its own caption buttons.
# Keep a real mapped window — withdrawn override-redirect is ignored.
wm title . Openbox
wm geometry . 1x1+-200+-200
wm attributes . -alpha 0.0
update idletasks
set id [winfo id .]
set dec 0
scan $id %x dec
set atoms "_NET_WM_MOVERESIZE,_NET_ACTIVE_WINDOW,_NET_WM_STATE,_NET_WM_STATE_MAXIMIZED_VERT,_NET_WM_STATE_MAXIMIZED_HORZ,_NET_WM_STATE_FULLSCREEN,_NET_WM_NAME,_NET_SUPPORTED,_NET_SUPPORTING_WM_CHECK,_NET_CLOSE_WINDOW,_NET_WM_MOVERESIZE"
catch {exec xprop -id $id -f WM_NAME 8s -set WM_NAME Openbox}
catch {exec xprop -id $id -f _NET_WM_NAME 8u -set _NET_WM_NAME Openbox}
catch {exec xprop -id $id -f _NET_SUPPORTING_WM_CHECK 32c -set _NET_SUPPORTING_WM_CHECK $dec}
catch {exec xprop -root -f _NET_SUPPORTING_WM_CHECK 32c -set _NET_SUPPORTING_WM_CHECK $dec}
catch {exec xprop -root -f _NET_SUPPORTED 32a -set _NET_SUPPORTED $atoms}
catch {exec xprop -root -f _NET_WM_NAME 8u -set _NET_WM_NAME Openbox}
catch {exec sh -c {echo DEEPOS_WM Openbox >/dev/ttyS0}}
vwait forever
""",
    )
    overlay_text(
        tree,
        "usr/bin/deepos-chrome-frame",
        r"""#!/bin/sh
# Force Chromium to draw minimize / maximize / close itself.
seed='{"browser":{"custom_chrome_frame":true},"bookmark_bar":{"show_on_all_tabs":false}}'
for dir in /root/.config/chromium /root/.config/chromium-browser; do
    mkdir -p "$dir/Default"
    for f in "$dir/Default/Preferences" "$dir"/Profile*/Preferences; do
        case $f in *'*'*) continue ;; esac
        if [ ! -f "$f" ]; then
            printf '%s\n' "$seed" > "$f"
            continue
        fi
        # Drop stale locks so the rewrite sticks.
        rm -f "$f.bak" "$dir/Default/LOCK" "$dir/Default/lockfile" 2>/dev/null
        if grep -q 'custom_chrome_frame' "$f"; then
            sed -i \
                -e 's/"custom_chrome_frame"[[:space:]]*:[[:space:]]*false/"custom_chrome_frame":true/g' \
                -e 's/"custom_chrome_frame"[[:space:]]*:[[:space:]]*False/"custom_chrome_frame":true/g' \
                "$f"
        elif grep -q '"browser"' "$f"; then
            sed -i \
                -e 's/"browser"[[:space:]]*:[[:space:]]*{/"browser":{"custom_chrome_frame":true,/' \
                "$f"
        else
            sed -i '1s/^{/{"browser":{"custom_chrome_frame":true},/' "$f"
        fi
    done
    # First profile seed when Default/Preferences was just created empty by mkdir path only.
    if [ ! -f "$dir/Default/Preferences" ]; then
        printf '%s\n' "$seed" > "$dir/Default/Preferences"
    fi
done
""",
        executable=True,
    )
    overlay_text(
        tree,
        "usr/bin/deepos-firefox-frame",
        r"""#!/bin/sh
# Make Firefox draw its own window buttons (client decorations).
prefs='user_pref("browser.tabs.inTitlebar", 1);
user_pref("browser.tabs.drawInTitlebar", true);
user_pref("widget.gtk.non-native-titlebar-buttons.enabled", true);
user_pref("browser.tabs.extraDragSpace", false);
'
write_user_js() {
    dir=$1
    [ -d "$dir" ] || return 0
    f="$dir/user.js"
    if [ -f "$f" ] && grep -q 'browser.tabs.inTitlebar' "$f"; then
        sed -i 's/user_pref("browser.tabs.inTitlebar", 0)/user_pref("browser.tabs.inTitlebar", 1)/' "$f"
    else
        printf '%s\n' "$prefs" >> "$f"
    fi
}
mkdir -p /root/.mozilla/firefox
if [ -f /root/.mozilla/firefox/profiles.ini ]; then
    for d in /root/.mozilla/firefox/*.default /root/.mozilla/firefox/*.default-release /root/.mozilla/firefox/*.default*; do
        case $d in *'*'*) continue ;; esac
        write_user_js "$d"
    done
else
    # Profile does not exist yet — seed one Firefox will adopt on first run.
    mkdir -p /root/.mozilla/firefox/deepos.default
    printf '%s\n' '[General]' 'StartWithLastProfile=1' '' '[Profile0]' 'Name=default' 'IsRelative=1' 'Path=deepos.default' 'Default=1' \
        > /root/.mozilla/firefox/profiles.ini
    printf '%s\n' "$prefs" > /root/.mozilla/firefox/deepos.default/user.js
fi
""",
        executable=True,
    )
    overlay_text(
        tree,
        "etc/deepos/settings",
        """RESOLUTION=1920x1080
UI_LANG=ru
KEYBOARD=us,ru
FONT_SIZE=12
VOLUME=70
TZ=Europe/Samara
""",
    )
    overlay_text(
        tree,
        "etc/deepos/Xresources",
        """XTerm*background: #1c1b19
XTerm*foreground: #f6f1ea
XTerm*cursorColor: #e7b48a
XTerm*faceName: DejaVu Sans Mono
XTerm*faceSize: 12
XTerm*scrollBar: true
XTerm*rightScrollBar: true
XTerm*scrollColor: #312e2b
XTerm*borderColor: #45403b
XTerm*color0: #1c1b19
XTerm*color1: #d4655d
XTerm*color2: #a3b18a
XTerm*color3: #e7b48a
XTerm*color4: #8d99ae
XTerm*color5: #c4a484
XTerm*color6: #d4c4b0
XTerm*color7: #f6f1ea
XTerm*color8: #b3aa9e
XTerm*color9: #e07a72
XTerm*color10: #b7c4a1
XTerm*color11: #f0d0b0
XTerm*color12: #aeb8c8
XTerm*color13: #d4b896
XTerm*color14: #e7d7c4
XTerm*color15: #fffaf4
XClock*background: #262421
XClock*foreground: #f6f1ea
XClock*hourColor: #e7b48a
XClock*minuteColor: #f6f1ea
XClock*secondColor: #d4655d
""",
    )
    overlay_text(
        tree,
        "usr/bin/deepos-settings-apply",
        r"""#!/bin/sh
CONF=/root/.deepos/settings
mkdir -p /root/.deepos /tmp
MODE=boot
if [ "$1" = "boot" ]; then
    MODE=boot
    shift
elif [ "$1" = "save" ]; then
    MODE=save
    shift
    touch "$CONF"
    grep -v -E '^(RESOLUTION|UI_LANG|KEYBOARD|FONT_SIZE|VOLUME)=' "$CONF" > "$CONF.tmp" 2>/dev/null || true
    echo "RESOLUTION=$1" >> "$CONF.tmp"
    echo "UI_LANG=$2" >> "$CONF.tmp"
    echo "KEYBOARD=$3" >> "$CONF.tmp"
    echo "FONT_SIZE=$4" >> "$CONF.tmp"
    echo "VOLUME=${5:-70}" >> "$CONF.tmp"
    mv "$CONF.tmp" "$CONF"
fi
if [ ! -f "$CONF" ]; then
    cp /etc/deepos/settings "$CONF"
fi
. "$CONF"
UI_LANG=${UI_LANG:-ru}
KEYBOARD=${KEYBOARD:-us,ru}
FONT_SIZE=${FONT_SIZE:-12}
VOLUME=${VOLUME:-70}

if [ ! -f /usr/share/deepos/desktop.tcl ] && [ ! -f /usr/share/deepos/desktop/index.html ]; then
    if [ "$UI_LANG" = "en" ]; then
        cp /usr/share/deepos/jwm-en.jwmrc /root/.jwmrc
    else
        cp /usr/share/deepos/jwm-ru.jwmrc /root/.jwmrc
    fi
    cp /root/.jwmrc /etc/jwm/system.jwmrc 2>/dev/null
fi

case "$KEYBOARD" in
    *[!A-Za-z,]*) KEYBOARD=us,ru ;;
esac
case "$KEYBOARD" in
    ru|us|ua|de|fr) setxkbmap -layout "$KEYBOARD" >/dev/null 2>&1 ;;
    *) setxkbmap -layout "$KEYBOARD" -option "grp:alt_shift_toggle" >/dev/null 2>&1 ;;
esac

xrdb -merge /etc/deepos/Xresources >/dev/null 2>&1
printf 'XTerm*faceSize: %s\n' "$FONT_SIZE" | xrdb -merge

status=OK
if [ -n "$RESOLUTION" ] && command -v xrandr >/dev/null 2>&1; then
    out=$(xrandr | awk '/ connected/{print $1; exit}')
    w=${RESOLUTION%x*}
    h=${RESOLUTION#*x}
    name="${w}x${h}_60.00"
    if [ -z "$out" ]; then
        status="ERR no display"
    else
        : > /tmp/deepos-xrandr.log
        if ! xrandr --output "$out" --mode "$RESOLUTION" >>/tmp/deepos-xrandr.log 2>&1 \
            && ! xrandr --output "$out" --mode "$name" >>/tmp/deepos-xrandr.log 2>&1; then
            line=""
            case "$RESOLUTION" in
                1024x768) line="63.50 1024 1072 1176 1328 768 771 775 798 -hsync +vsync" ;;
                1280x720) line="74.50 1280 1344 1472 1664 720 723 728 748 -hsync +vsync" ;;
                1280x800) line="83.50 1280 1352 1480 1680 800 803 809 831 -hsync +vsync" ;;
                1366x768) line="85.25 1366 1436 1579 1792 768 771 774 798 -hsync +vsync" ;;
                1600x900) line="118.25 1600 1696 1856 2112 900 903 908 934 -hsync +vsync" ;;
                1920x1080) line="173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync" ;;
            esac
            if [ -z "$line" ]; then
                status="ERR mode"
            else
                # shellcheck disable=SC2086
                xrandr --newmode "$name" $line >>/tmp/deepos-xrandr.log 2>&1
                xrandr --addmode "$out" "$name" >>/tmp/deepos-xrandr.log 2>&1
                if ! xrandr --output "$out" --mode "$name" >>/tmp/deepos-xrandr.log 2>&1; then
                    status="ERR mode"
                fi
            fi
        fi
    fi
fi
if command -v amixer >/dev/null 2>&1; then
    amixer -q sset Master "${VOLUME:-70}%" unmute >/dev/null 2>&1
    amixer -q sset PCM "${VOLUME:-70}%" unmute >/dev/null 2>&1
fi
printf '%s\n' "$status" > /tmp/deepos-settings.status
if [ "$MODE" = "save" ] && [ ! -f /usr/share/deepos/desktop.tcl ] && [ ! -f /usr/share/deepos/desktop/index.html ]; then
    jwm -restart >/dev/null 2>&1
fi
exit 0
""",
        executable=True,
    )
    overlay_text(
        tree,
        "usr/bin/deepos-settings",
        """#!/bin/sh
export DISPLAY=${DISPLAY:-:0}
exec wish /usr/share/deepos/settings.tcl "$@"
""",
        executable=True,
    )
    overlay_text(
        tree,
        "usr/share/deepos/settings.tcl",
        r"""#!/usr/bin/wish
package require Tk

set conf /root/.deepos/settings
set resolution 1920x1080
set ui_lang ru
set keyboard us,ru
set font_size 12
if {[file exists $conf]} {
    set fh [open $conf r]
    while {[gets $fh line] >= 0} {
        if {[regexp {^RESOLUTION=(.*)$} $line -> v] && $v ne ""} { set resolution $v }
        if {[regexp {^UI_LANG=(.*)$} $line -> v]} { set ui_lang $v }
        if {[regexp {^KEYBOARD=(.*)$} $line -> v]} { set keyboard $v }
        if {[regexp {^FONT_SIZE=(.*)$} $line -> v]} { set font_size $v }
    }
    close $fh
}

wm title . "DeepOS — Настройки"
wm geometry . 560x640
wm resizable . 0 0
. configure -bg #1c1b19

font create brand -family "DejaVu Sans" -size 11
font create brandb -family "DejaVu Sans" -size 12 -weight bold
font create brandh -family "DejaVu Sans" -size 22 -weight bold
font create mono -family "DejaVu Sans Mono" -size 10

frame .top -bg #262421 -height 92
pack .top -side top -fill x
label .top.kicker -text "DEEP EDITION" -bg #262421 -fg #e7b48a -font mono
label .top.title -text "НАСТРОЙКИ" -bg #262421 -fg #e7b48a -font brandh
label .top.sub -text "Independent  ·  Operating System" -bg #262421 -fg #b3aa9e -font mono
pack .top.kicker .top.title .top.sub -anchor w -padx 22 -pady 1
pack configure .top.kicker -pady {14 0}

frame .body -bg #1c1b19
pack .body -side top -fill both -expand 1 -padx 22 -pady 12

proc section {parent title} {
    label $parent -text $title -bg #1c1b19 -fg #e7b48a -font brandb -anchor w
    pack $parent -fill x -pady {8 4}
}

section .body.s1 "ЭКРАН"
frame .body.res -bg #262421
pack .body.res -fill x
listbox .body.res.list -height 6 -bg #262421 -fg #f6f1ea \
    -selectbackground #312e2b -selectforeground #e7b48a \
    -highlightthickness 1 -highlightcolor #e7b48a -highlightbackground #312e2b \
    -font brand -bd 0 -activestyle none -exportselection 0
pack .body.res.list -fill x -padx 8 -pady 8
foreach mode {1024x768 1280x720 1280x800 1366x768 1600x900 1920x1080} {
    .body.res.list insert end $mode
}
set idx [lsearch -exact {1024x768 1280x720 1280x800 1366x768 1600x900 1920x1080} $resolution]
if {$idx < 0} { set idx 5 }
.body.res.list selection set $idx
.body.res.list see $idx

section .body.s2 "ЯЗЫК ИНТЕРФЕЙСА"
frame .body.lang -bg #1c1b19
pack .body.lang -fill x
radiobutton .body.lang.ru -text "Русский" -variable ui_lang -value ru \
    -bg #1c1b19 -fg #f6f1ea -selectcolor #e7b48a -activebackground #1c1b19 \
    -activeforeground #e7b48a -font brand -highlightthickness 0
radiobutton .body.lang.en -text "English" -variable ui_lang -value en \
    -bg #1c1b19 -fg #f6f1ea -selectcolor #e7b48a -activebackground #1c1b19 \
    -activeforeground #e7b48a -font brand -highlightthickness 0
pack .body.lang.ru .body.lang.en -side left -padx 8

section .body.s3 "КЛАВИАТУРА"
frame .body.kb -bg #1c1b19
pack .body.kb -fill x
radiobutton .body.kb.both -text "EN + RU   Alt+Shift" -variable keyboard -value us,ru \
    -bg #1c1b19 -fg #f6f1ea -selectcolor #c4a484 -activebackground #1c1b19 \
    -activeforeground #e7b48a -font brand -highlightthickness 0
radiobutton .body.kb.ru -text "RU" -variable keyboard -value ru \
    -bg #1c1b19 -fg #f6f1ea -selectcolor #c4a484 -activebackground #1c1b19 \
    -activeforeground #e7b48a -font brand -highlightthickness 0
radiobutton .body.kb.us -text "EN" -variable keyboard -value us \
    -bg #1c1b19 -fg #f6f1ea -selectcolor #c4a484 -activebackground #1c1b19 \
    -activeforeground #e7b48a -font brand -highlightthickness 0
pack .body.kb.both .body.kb.ru .body.kb.us -side left -padx 8

section .body.s4 "ШРИФТ ТЕРМИНАЛА"
frame .body.font -bg #1c1b19
pack .body.font -fill x
foreach size {11 12 14 16} {
    radiobutton .body.font.s$size -text $size -variable font_size -value $size \
        -bg #1c1b19 -fg #f6f1ea -selectcolor #e7b48a -activebackground #1c1b19 \
        -activeforeground #e7b48a -font brand -highlightthickness 0
    pack .body.font.s$size -side left -padx 8
}

label .status -text "Изменения действуют до выключения DeepOS." \
    -bg #1c1b19 -fg #b3aa9e -font mono -anchor w
pack .status -fill x -padx 22

frame .buttons -bg #1c1b19
pack .buttons -side bottom -fill x -padx 22 -pady 16
button .buttons.apply -text "ПРИМЕНИТЬ" -font brandb -relief flat -bd 0 \
    -bg #e7b48a -fg #1c1b19 -activebackground #e7b48a -activeforeground #1c1b19 \
    -command apply_settings -padx 18 -pady 8
button .buttons.close -text "ЗАКРЫТЬ" -font brandb -relief flat -bd 0 \
    -bg #312e2b -fg #f6f1ea -activebackground #c4a484 -activeforeground #f6f1ea \
    -command {exit} -padx 18 -pady 8
pack .buttons.apply .buttons.close -side left -padx 6

proc apply_settings {} {
    set sel [.body.res.list curselection]
    if {$sel eq ""} {
        .status configure -text "Выберите разрешение." -fg #d4655d
        return
    }
    set mode [.body.res.list get $sel]
    set rc [catch {exec /usr/bin/deepos-settings-apply save $mode $::ui_lang $::keyboard $::font_size} err]
    set msg "Готово: $mode"
    if {[file exists /tmp/deepos-settings.status]} {
        set fh [open /tmp/deepos-settings.status r]
        set line [string trim [read $fh]]
        close $fh
        if {[string match ERR* $line]} {
            .status configure -text "Не удалось сменить разрешение." -fg #d4655d
            return
        }
    }
    if {$rc != 0} {
        .status configure -text "Ошибка применения." -fg #d4655d
        return
    }
    .status configure -text $msg -fg #e7b48a
}
""",
    )
    overlay_text(
        tree,
        "usr/bin/deepos-term",
        """#!/bin/sh
FONT_SIZE=12
TERM_BG=0c0c0c
TERM_FG=cccccc
if [ -f /root/.deepos/settings ]; then
    . /root/.deepos/settings
fi
TERM_BG=$(printf '%s' "$TERM_BG" | tr -d '#')
TERM_FG=$(printf '%s' "$TERM_FG" | tr -d '#')
TERM_BG="#${TERM_BG:-0c0c0c}"
TERM_FG="#${TERM_FG:-cccccc}"
exec xterm -fa "DejaVu Sans Mono" -fs "${FONT_SIZE:-12}" -title "DeepOS" \
    -bg "$TERM_BG" -fg "$TERM_FG" -cr "#e7b48a" "$@"
""",
        executable=True,
    )
    overlay_text(
        tree,
        "usr/bin/deepos-welcome",
        """#!/bin/sh
if [ -f /tmp/deepos-welcomed ]; then
    exit 0
fi
touch /tmp/deepos-welcomed
xclock -update 1 -geometry 148x148-28+52 &
deepos-term -geometry 78x18+36+52 -e /usr/bin/deepos-greet &
""",
        executable=True,
    )
    overlay_text(
        tree,
        "usr/bin/deepos-greet",
        """#!/bin/sh
UI_LANG=ru
if [ -f /root/.deepos/settings ]; then
    . /root/.deepos/settings
fi
cat /etc/motd
echo
if [ "$UI_LANG" = "en" ]; then
    echo "DeepOS desktop. Deep Cyan / Deep Purple."
    echo "Open Settings from the DeepOS menu to change resolution and language."
    echo "Alt+T terminal. Alt+S settings."
else
    echo "Рабочий стол DeepOS. Цвета Deep Cyan и Deep Purple."
    echo "Настройки — в меню DeepOS: разрешение, язык, клавиатура, шрифт."
    echo "Alt+T терминал. Alt+S настройки."
fi
echo
exec /bin/sh
""",
        executable=True,
    )
    desk = ROOT / "desktop"
    for name, dest, exe in (
        ("desktop.tcl", "usr/share/deepos/desktop.tcl", True),
    ):
        overlay_text(tree, dest, (desk / name).read_text(encoding="utf-8"), executable=exe)
    notes = (desk / "changelog.txt").read_text(encoding="utf-8")
    overlay_text(tree, "usr/share/deepos/changelog", f"DeepOS {version}\n\n{notes}")
    sound_dir = desk / "sounds"
    if sound_dir.is_dir():
        for wav in sorted(sound_dir.glob("*.wav")):
            add_node(
                tree,
                f"usr/share/deepos/sounds/{wav.name}",
                FsNode("reg", 0o100644, wav.read_bytes()),
            )
    readme = (desk / "readme.txt").read_text(encoding="utf-8").splitlines()
    if readme:
        readme[0] = f"DeepOS {version}"
    overlay_text(tree, "root/readme.txt", "\n".join(readme) + "\n")
    font_file = desk / "fonts" / "Unbounded-SemiBold.ttf"
    if font_file.exists():
        add_node(
            tree,
            "usr/share/fonts/unbounded/Unbounded-SemiBold.ttf",
            FsNode("reg", 0o100644, font_file.read_bytes()),
        )
    cascadia = desk / "fonts" / "CascadiaMono.ttf"
    if cascadia.exists():
        add_node(
            tree,
            "usr/share/fonts/cascadia/CascadiaMono.ttf",
            FsNode("reg", 0o100644, cascadia.read_bytes()),
        )
    overlay_text(tree, "root/.jwmrc", (desk / "shell.jwmrc").read_text(encoding="utf-8"))
    overlay_text(
        tree,
        "usr/share/glib-2.0/schemas/10_deepos.gschema.override",
        """[org.gnome.Epiphany]
ask-for-default=false
content-filters=@as []
restore-session-policy='crashed'
""",
    )
    overlay_text(
        tree,
        "usr/bin/deepos-browser",
        """#!/bin/sh
export DISPLAY=${DISPLAY:-:0}
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
export GSK_RENDERER=cairo
export GDK_DISABLE=vulkan,gl,dmabuf
export GDK_BACKEND=x11
unset LIBGL_ALWAYS_SOFTWARE
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/runtime}
exec >>/var/log/browser.log 2>&1
echo "browser start $(date +%s)"
i=0
while [ "$i" -lt 40 ]; do
    busybox wget -q -T 1 -O /dev/null http://127.0.0.1:8765/ && break
    i=$((i + 1))
    sleep 0.1
done
echo "server wait=$i $(date +%s)"
exec epiphany --kiosk-mode http://127.0.0.1:8765/
echo "epiphany exit $?"
""",
        executable=True,
    )
    if "bin/sh" not in tree and "bin/busybox" in tree:
        add_node(tree, "bin/sh", FsNode("lnk", 0o120777, b"busybox"))
    # apk looks for keys in /etc/apk/keys
    key_sources = [path for path in tree if path.startswith("usr/share/apk/keys/") and tree[path].kind == "reg"]
    for src in key_sources:
        name = src.rsplit("/", 1)[-1]
        dest = f"etc/apk/keys/{name}"
        if dest not in tree:
            add_node(tree, dest, FsNode("reg", 0o100644, tree[src].data))


def cpio_pad(size: int) -> int:
    return (4 - (size % 4)) % 4


def write_cpio(tree: dict[str, FsNode], dest: Path) -> None:
    def sort_key(item: tuple[str, FsNode]) -> tuple:
        path, node = item
        return (path.count("/"), 0 if node.kind == "dir" else 1, path)

    blob = bytearray()
    inode = 1

    def emit(name: str, mode: int, body: bytes = b"", rmajor: int = 0, rminor: int = 0) -> None:
        nonlocal inode
        name_bytes = name.encode("utf-8") + b"\0"
        header = (
            f"{0o070701:06o}"
            f"{inode:08X}"
            f"{mode:08X}"
            f"{0:08X}{0:08X}{1:08X}"
            f"{int(time.time()) & 0xFFFFFFFF:08X}"
            f"{len(body):08X}"
            f"{0:08X}{0:08X}"
            f"{rmajor:08X}{rminor:08X}"
            f"{len(name_bytes):08X}"
            f"{0:08X}"
        ).encode("ascii")
        if len(header) != 110:
            raise RuntimeError(f"bad cpio header length {len(header)}")
        blob.extend(header)
        blob.extend(name_bytes)
        blob.extend(b"\0" * cpio_pad(110 + len(name_bytes)))
        blob.extend(body)
        blob.extend(b"\0" * cpio_pad(len(body)))
        inode += 1

    emit(".", stat.S_IFDIR | 0o755)
    for path, node in sorted(tree.items(), key=sort_key):
        if node.kind == "dir":
            emit(path, node.mode or (stat.S_IFDIR | 0o755))
        elif node.kind == "lnk":
            emit(path, node.mode or (stat.S_IFLNK | 0o777), node.data)
        elif node.kind == "chr":
            emit(path, node.mode or stat.S_IFCHR, rmajor=node.rmajor, rminor=node.rminor)
        elif node.kind == "blk":
            emit(path, node.mode or stat.S_IFBLK, rmajor=node.rmajor, rminor=node.rminor)
        elif node.kind == "fifo":
            emit(path, node.mode or stat.S_IFIFO)
        else:
            emit(path, node.mode or (stat.S_IFREG | 0o644), node.data)
    emit("TRAILER!!!", 0)

    dest.parent.mkdir(parents=True, exist_ok=True)
    with gzip.GzipFile(filename=str(dest), mode="wb", compresslevel=6, mtime=0) as gz:
        gz.write(blob)


def detect_branch() -> str:
    url = "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/latest-releases.yaml"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp:
        text = resp.read().decode("utf-8", "replace")
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("branch:"):
            branch = line.split(":", 1)[1].strip()
            if branch.startswith("v"):
                return branch
    raise RuntimeError("cannot detect alpine branch from latest-releases.yaml")


def main() -> int:
    log("DeepOS build")
    branch = detect_branch()
    branch_root = f"https://dl-cdn.alpinelinux.org/alpine/{branch}"
    log(f"Alpine package branch: {branch}")
    by_name, providers = load_indexes(branch_root)
    packages = resolve(by_name, providers, ROOT_PACKAGES)
    total = sum(int(pkg.get("S") or 0) for pkg in packages)
    log(f"Packages: {len(packages)}, download size ~ {total / (1024 * 1024):.1f} MiB")
    for pkg in packages:
        log(f"  {pkg['P']}-{pkg['V']} ({pkg['repo']})")

    tree: dict[str, FsNode] = {}
    kernel_out: list[bytes] = []
    for pkg in packages:
        filename = f"{pkg['P']}-{pkg['V']}.apk"
        dest = APK_CACHE / pkg["repo"] / filename
        url = f"{pkg['repo_base']}/{filename}"
        download(url, dest, expected=int(pkg.get("S") or 0) or None)
        blob = dest.read_bytes()
        payloads = gzip_payloads(blob)
        if not payloads:
            raise RuntimeError(f"no tar payload in {filename}")
        for payload in payloads:
            ingest_tar(tree, payload, kernel_out)
        log(f"  installed {pkg['P']}")

    xcomp = APK_CACHE / "xcompmgr-1.1.10-r0.apk"
    if not xcomp.exists():
        download(
            "https://dl-cdn.alpinelinux.org/alpine/edge/testing/x86_64/xcompmgr-1.1.10-r0.apk",
            xcomp,
        )
    for payload in gzip_payloads(xcomp.read_bytes()):
        ingest_tar(tree, payload, kernel_out)
    log("  installed xcompmgr")

    if not kernel_out:
        raise RuntimeError("linux-virt package did not contain vmlinuz")
    kernel = kernel_out[-1]
    if b"HdrS" not in kernel[:1024]:
        raise RuntimeError("vmlinuz does not look like a Linux bzImage")

    version = next_build_version()
    log(f"DeepOS {version}")
    apply_overlay(tree, branch, version)
    if "bin/busybox" not in tree and "bin/sh" not in tree:
        raise RuntimeError("userspace is missing /bin/sh")

    OUT.mkdir(parents=True, exist_ok=True)
    kernel_path = OUT / "vmlinuz"
    initrd_path = OUT / "deepos-rootfs.cpio.gz"
    kernel_path.write_bytes(kernel)
    write_cpio(tree, initrd_path)
    log(f"kernel: {kernel_path} ({kernel_path.stat().st_size} bytes)")
    log(f"initrd: {initrd_path} ({initrd_path.stat().st_size} bytes)")
    log(f"rootfs entries: {len(tree)}")
    log("DeepOS image is ready")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as exc:  # noqa: BLE001
        log(f"error: {exc}")
        sys.exit(1)
