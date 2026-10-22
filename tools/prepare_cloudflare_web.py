#!/usr/bin/env python3
"""Build builds/web-cf from builds/web for Cloudflare's 25 MiB file limit.

Run after a Godot Web export to builds/web/:
  python tools/prepare_cloudflare_web.py
Then:
  npx wrangler deploy
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

try:
	import brotli
except ImportError:
	print("Install brotli first: pip install brotli", file=sys.stderr)
	sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "builds" / "web"
OUT = ROOT / "builds" / "web-cf"


def main() -> int:
	if not (SRC / "index.wasm").is_file():
		print(f"Missing {SRC / 'index.wasm'} — export Web (HTML5) to builds/web first.", file=sys.stderr)
		return 1

	if OUT.exists():
		shutil.rmtree(OUT)
	shutil.copytree(SRC, OUT)
	shutil.copy2(ROOT / "audio" / "music" / "menu_farmyard_loop.ogg", OUT / "menu_farmyard_loop.ogg")

	wasm = OUT / "index.wasm"
	raw = wasm.read_bytes()
	if raw[:4] != b"\x00asm":
		print("index.wasm does not look like uncompressed WASM; aborting.", file=sys.stderr)
		return 1

	comp = brotli.compress(raw, quality=5)
	wasm.write_bytes(comp)
	print(f"WASM {len(raw) / 1024 / 1024:.2f} MiB -> {len(comp) / 1024 / 1024:.2f} MiB (brotli)")
	print(f"Ready: {OUT}")
	print("Deploy with: npx wrangler deploy")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
