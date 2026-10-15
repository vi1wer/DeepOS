#!/usr/bin/env python3
"""Download a relocatable QEMU build from MSYS2 into tools/qemu."""

from __future__ import annotations

import io
import shutil
import sys
import tarfile
import urllib.request
import zstandard
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "cache" / "msys2"
DEST = ROOT / "tools" / "qemu"
DB_URL = "https://repo.msys2.org/mingw/mingw64/mingw64.db.tar.zst"
PKG_BASE = "https://repo.msys2.org/mingw/mingw64/"
ROOT_PKG = "mingw-w64-x86_64-qemu"
USER_AGENT = "DeepOS-builder/1.0"


def log(msg: str) -> None:
    print(msg, flush=True)


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 0:
        return
    tmp = dest.with_suffix(dest.suffix + ".part")
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    log(f"  download {url}")
    with urllib.request.urlopen(req, timeout=180) as resp, tmp.open("wb") as out:
        shutil.copyfileobj(resp, out)
    tmp.replace(dest)


def parse_desc(text: str) -> dict:
    fields: dict[str, list[str]] = {}
    key = None
    for line in text.splitlines():
        if line.startswith("%") and line.endswith("%") and len(line) > 2:
            key = line[1:-1]
            fields[key] = []
        elif key is not None and line:
            fields[key].append(line)
    return fields


def dep_name(raw: str) -> str:
    name = raw
    for sep in (">=", "<=", "=", ">", "<"):
        name = name.split(sep)[0]
    return name.strip()


def load_db(blob: bytes) -> dict[str, dict]:
    decompressor = zstandard.ZstdDecompressor()
    with decompressor.stream_reader(io.BytesIO(blob)) as reader:
        data = reader.read()
    packages: dict[str, dict] = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:") as tar:
        for member in tar.getmembers():
            if not member.name.endswith("/desc"):
                continue
            extracted = tar.extractfile(member)
            if extracted is None:
                continue
            fields = parse_desc(extracted.read().decode("utf-8", "replace"))
            name = fields.get("NAME", [""])[0]
            if name:
                packages[name] = fields
    return packages


def resolve(packages: dict[str, dict], root: str) -> list[dict]:
    providers: dict[str, str] = {}
    for name, fields in packages.items():
        providers[name] = name
        for item in fields.get("PROVIDES", []):
            providers.setdefault(dep_name(item), name)

    selected: list[dict] = []
    seen: set[str] = set()

    def visit(name: str) -> None:
        real = providers.get(name)
        if real is None or real in seen:
            if real is None:
                log(f"warning: missing dependency {name}")
            return
        seen.add(real)
        for dep in packages[real].get("DEPENDS", []):
            visit(dep_name(dep))
        selected.append(packages[real])

    visit(root)
    return selected


def extract_package(path: Path, dest: Path) -> None:
    decompressor = zstandard.ZstdDecompressor()
    with path.open("rb") as raw:
        reader = decompressor.stream_reader(raw)
        with tarfile.open(fileobj=reader, mode="r|") as tar:
            pending_links: list[tuple[str, str]] = []
            for member in tar:
                name = member.name.replace("\\", "/").lstrip("./")
                if not name or name.endswith("/"):
                    continue
                target = dest / name
                if member.issym() or member.islnk():
                    pending_links.append((name, member.linkname))
                    continue
                if not member.isreg():
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                src = tar.extractfile(member)
                if src is None:
                    continue
                with target.open("wb") as out:
                    shutil.copyfileobj(src, out)
            for name, link in pending_links:
                target = dest / name
                link_path = Path(link)
                source = (target.parent / link_path).resolve() if not link_path.is_absolute() else dest / link_path.as_posix().lstrip("/")
                if source.exists() and source.is_file():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, target)


def main() -> int:
    CACHE.mkdir(parents=True, exist_ok=True)
    db_path = CACHE / "mingw64.db.tar.zst"
    download(DB_URL, db_path)
    packages = load_db(db_path.read_bytes())
    selected = resolve(packages, ROOT_PKG)
    total = 0
    for fields in selected:
        csize = fields.get("CSIZE", ["0"])[0]
        total += int(csize or 0)
    log(f"QEMU packages: {len(selected)}, download ~ {total / (1024 * 1024):.1f} MiB")
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.mkdir(parents=True)
    for fields in selected:
        filename = fields["FILENAME"][0]
        dest = CACHE / filename
        download(PKG_BASE + filename, dest)
        log(f"  extract {fields['NAME'][0]}")
        extract_package(dest, DEST)
    exe = DEST / "mingw64" / "bin" / "qemu-system-x86_64.exe"
    if not exe.exists():
        raise RuntimeError(f"qemu binary missing at {exe}")
    log(f"QEMU ready: {exe}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001
        log(f"error: {exc}")
        sys.exit(1)
