from pathlib import Path

path = Path(r"d:\DeepOS\desktop\desktop.tcl")
text = path.read_text(encoding="utf-8")
for name in ("PANEL2", "PANEL", "CYAN", "PURPLE", "MAGENTA", "ACCENT", "WHITE", "GRAY", "BG"):
    text = text.replace("$" + name, "$::" + name)
text = text.replace("$::::", "$::")
path.write_bytes(text.replace("\r\n", "\n").encode("utf-8"))
data = path.read_bytes()
print("panel", data.count(b"$::PANEL"), "cr", data.count(b"\r"))
