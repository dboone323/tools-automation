#!/usr/bin/env python3
"""
Simple asset build script:
- hashes CSS/JS/SVG files in static/ and copies them with content-hash suffix
- writes asset-manifest.json mapping logical names to hashed filenames

Usage: python build_assets.py
"""
import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent
STATIC_DIR = ROOT / "static"
MANIFEST_PATH = STATIC_DIR / "asset-manifest.json"

FILES = {
    "mcp_dashboard.css": STATIC_DIR / "mcp_dashboard.css",
    "mcp_dashboard.js": STATIC_DIR / "mcp_dashboard.js",
    "favicon.svg": STATIC_DIR / "favicon.svg",
    "manifest.webmanifest": STATIC_DIR / "manifest.webmanifest",
}


def hash_file(path: Path) -> str:
    h = hashlib.sha1()
    with path.open("rb") as f:
        while True:
            chunk = f.read(8192)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()[:10]


def build():
    manifest = {}
    for logical, path in FILES.items():
        if not path.exists():
            print(f"Skipping missing asset: {path}")
            continue
        h = hash_file(path)
        ext = path.suffix
        name = path.stem
        hashed_name = f"{name}.{h}{ext}"
        dest = path.parent / hashed_name
        # copy if not exists
        if not dest.exists():
            with path.open("rb") as src, dest.open("wb") as dst:
                dst.write(src.read())
        manifest[logical] = hashed_name

    with MANIFEST_PATH.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    print(f"Wrote manifest to {MANIFEST_PATH}")


if __name__ == "__main__":
    build()
