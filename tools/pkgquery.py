import tarfile
from pathlib import Path


def load(repo: str) -> dict:
    pkgs = []
    with tarfile.open(Path(r"d:\DeepOS\cache") / f"APKINDEX-{repo}.tar.gz", "r:gz") as tar:
        text = tar.extractfile("APKINDEX").read().decode("utf-8", "replace")
    cur = {}
    for line in text.splitlines():
        if not line:
            if cur.get("P"):
                pkgs.append(cur)
            cur = {}
            continue
        if len(line) > 2 and line[1] == ":":
            key, value = line[0], line[2:]
            if key in cur and key in "Dp":
                cur[key] += " " + value
            else:
                cur[key] = value
    if cur.get("P"):
        pkgs.append(cur)
    best = {}
    for pkg in pkgs:
        name = pkg["P"]
        if name not in best:
            best[name] = pkg
    return best


allp = {**load("main"), **load("community")}
names = [
    "cog", "surf", "luakit", "midori", "netsurf", "dillo", "badwolf",
    "epiphany", "firefox-esr", "chromium", "wpewebkit", "webkit2gtk",
    "python3", "py3-aiohttp", "ttf-liberation", "font-liberation",
    "font-noto", "font-noto-emoji",
]
for name in names:
    pkg = allp.get(name)
    if not pkg:
        print(f"MISSING {name}")
        continue
    size = int(pkg.get("S") or 0) / 1024 / 1024
    print(f"{name}-{pkg['V']} {size:.1f} MiB")
