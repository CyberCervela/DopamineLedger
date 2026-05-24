#!/usr/bin/env python3
"""
generate-pixel-icons.py — PixelLab.ai batch icon generator for round 2.

Usage:
    ./generate-pixel-icons.py --dry-run
    ./generate-pixel-icons.py --execute

ALWAYS run with --dry-run first. It prints:
    - the queue (filenames + prompts + endpoint + parameters)
    - the output directory
    - the estimated credit cost
Only run with --execute after the user has approved the queue.

Secrets:
    The PixelLab API key lives in ~/.dopamine-ledger.env as:
        PIXELLAB_API_KEY=...
    The file must be chmod 600. This script reads it via env var so the
    key NEVER appears on a command line (shell history) and NEVER in
    chat transcripts.

Endpoints:
    pixflux  — text-to-image. Use for ANCHOR generations (the first
               rendering of a new role with no reference image).
    bitforge — style-conditioned. Use for batch consistency once an
               anchor for that visual family exists. style_image must
               be EXACTLY the same dimensions as the requested output
               (use PIL nearest-neighbor upscale if needed).

Enum-valued params take specific strings, not adjectives:
    outline:  "single color black outline" | "selective outline" | "lineless"
    shading:  "basic shading" | "detailed shading" | "flat shading"
    (Round 1 burned hours discovering "thick" and "flat" aren't enums.)
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import time
from typing import Any

try:
    import requests  # noqa: F401  (only needed for --execute)
except ImportError:
    requests = None  # type: ignore[assignment]

# ---------------------------------------------------------------------
# Config — edit here, then --dry-run to inspect, then --execute.
# ---------------------------------------------------------------------

OUTPUT_DIR = pathlib.Path("PixelArt/generated")
CREDIT_COST_PER_CALL = 1  # rough; check PixelLab dashboard for actuals

PIXFLUX_ENDPOINT  = "https://api.pixellab.ai/v1/generate-image-pixflux"
BITFORGE_ENDPOINT = "https://api.pixellab.ai/v1/generate-image-bitforge"

# Common style defaults — tweak per request via overrides.
DEFAULT_STYLE = {
    "outline": "single color black outline",
    "shading": "basic shading",
    "detail":  "low detail",
    "view":    "side",
    "isometric": False,
    "no_background": True,
}

# The queue. Each entry produces one image.
QUEUE: list[dict[str, Any]] = [
    {
        "out":       "pixel.charger.png",
        "endpoint":  "pixflux",
        "prompt":    "a glowing yellow lightning bolt icon, 32x32 pixel art, "
                     "centered on transparent background",
        "size":      (32, 32),
    },
    {
        "out":       "pixel.spender.png",
        "endpoint":  "pixflux",
        "prompt":    "a dark hourglass icon dripping sand, 32x32 pixel art, "
                     "centered on transparent background",
        "size":      (32, 32),
    },
    {
        "out":       "pixel.quest.png",
        "endpoint":  "pixflux",
        "prompt":    "a wax-sealed scroll icon with a green checkmark, 32x32 pixel art, "
                     "centered on transparent background",
        "size":      (32, 32),
    },
    # Add more roles here — keep filename matching pixelArtAssetName(for:)
    # in IconResolver.swift. See SemanticIcon for the full list.
]

# ---------------------------------------------------------------------

def read_api_key() -> str:
    env_path = pathlib.Path.home() / ".dopamine-ledger.env"
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            if line.startswith("PIXELLAB_API_KEY="):
                return line.split("=", 1)[1].strip()
    # Fall back to env var if the user prefers exporting it.
    key = os.environ.get("PIXELLAB_API_KEY")
    if not key:
        sys.exit(
            "PIXELLAB_API_KEY not found. Either:\n"
            "  echo 'PIXELLAB_API_KEY=...' > ~/.dopamine-ledger.env && chmod 600 ~/.dopamine-ledger.env\n"
            "  or: export PIXELLAB_API_KEY=...   (only in your own shell, never on a Claude command line)"
        )
    return key


def print_queue() -> None:
    print(f"Output directory: {OUTPUT_DIR}")
    print(f"Queue ({len(QUEUE)} items, est. cost: {len(QUEUE) * CREDIT_COST_PER_CALL} credits):\n")
    for i, item in enumerate(QUEUE, start=1):
        print(f"  [{i:>2}] {item['out']}")
        print(f"       endpoint: {item['endpoint']}")
        print(f"       size:     {item['size']}")
        print(f"       prompt:   {item['prompt']}")
        print()


def call_pixflux(api_key: str, item: dict[str, Any]) -> bytes:
    w, h = item["size"]
    payload = {
        "description":   item["prompt"],
        "image_size":    {"width": w, "height": h},
        **DEFAULT_STYLE,
    }
    r = requests.post(
        PIXFLUX_ENDPOINT,
        headers={"Authorization": f"Bearer {api_key}"},
        json=payload,
        timeout=120,
    )
    r.raise_for_status()
    data = r.json()
    # The API returns base64 in data["image"]["base64"] (verify in dry-run logs).
    import base64
    return base64.b64decode(data["image"]["base64"])


def call_bitforge(api_key: str, item: dict[str, Any]) -> bytes:
    raise NotImplementedError(
        "Bitforge requires a style_image of matching dimensions. Add the "
        "anchor path + PIL upscale logic when you queue your first batch."
    )


def execute_queue(api_key: str) -> None:
    if requests is None:
        sys.exit("The 'requests' package is required for --execute. pip3 install --user requests")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for i, item in enumerate(QUEUE, start=1):
        out_path = OUTPUT_DIR / item["out"]
        print(f"[{i}/{len(QUEUE)}] {item['out']} ...", flush=True)

        if item["endpoint"] == "pixflux":
            png_bytes = call_pixflux(api_key, item)
        elif item["endpoint"] == "bitforge":
            png_bytes = call_bitforge(api_key, item)
        else:
            sys.exit(f"unknown endpoint: {item['endpoint']}")

        out_path.write_bytes(png_bytes)
        print(f"     wrote {out_path} ({len(png_bytes)} bytes)")

        # Be polite to the API.
        time.sleep(0.5)

    print("\nDone. Drop these into your asset catalog as pixel.<role>.imageset.")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = p.add_mutually_exclusive_group(required=True)
    group.add_argument("--dry-run", action="store_true", help="Print the queue and exit (no API calls)")
    group.add_argument("--execute", action="store_true", help="Actually call the API and write PNGs")
    args = p.parse_args()

    if args.dry_run:
        print_queue()
        print("Dry run only. No API calls made.")
        return

    api_key = read_api_key()
    print_queue()
    print("Proceeding with --execute in 3s... (Ctrl-C to abort)")
    time.sleep(3)
    execute_queue(api_key)


if __name__ == "__main__":
    main()
