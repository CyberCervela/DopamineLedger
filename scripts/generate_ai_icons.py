#!/usr/bin/env python3
"""
generate_ai_icons.py
Uses Imagen 4 Ultra via the Google AI API to generate four app icon candidates
for Dopamine Ledger, then saves them to the AppIcon.appiconset folder.

Candidates:
  ai_icon_A.png — Neumorphic lightning bolt, neutral palette
  ai_icon_B.png — Neumorphic lightning bolt, with charcoal accent
  ai_icon_C.png — Neumorphic DL monogram, neutral (raised letters)
  ai_icon_D.png — Neumorphic DL monogram, with dark + red accent colours
"""

import os, sys, warnings
warnings.filterwarnings("ignore")
from google import genai
from google.genai import types
from PIL import Image
import io

API_KEY = "REDACTED"
MODEL   = "imagen-4.0-ultra-generate-001"

OUTDIR = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..",
                 "DopamineLedger", "Assets.xcassets", "AppIcon.appiconset")
)

# The colour palette description used across all prompts so Imagen keeps
# the background consistent with NeuTheme (#E8E8EE cool off-white).
PALETTE = (
    "pale cool off-white gray background (hex #E8E8EE), "
    "white soft-glow shadow on the upper-left, "
    "muted blue-gray shadow on the lower-right"
)

PROMPTS = {
    "ai_icon_A.png": (
        f"A premium iOS app icon with a neumorphic soft-UI design. "
        f"A single large bold lightning bolt centred on a {PALETTE}. "
        "The bolt is the same hue as the background — its form defined purely "
        "by the dual neumorphic shadows that make it appear raised and tactile. "
        "Clean, minimal, no text, no decorations, no gradients other than the shadow."
    ),
    "ai_icon_B.png": (
        f"A premium iOS app icon. Neumorphic design. A single bold lightning bolt "
        f"centred on a {PALETTE}. "
        "The bolt itself is filled with deep charcoal (#2D2D3E), "
        "making it stand out against the soft gray background while the "
        "neumorphic shadows add 3-D depth around it. "
        "Modern, clean, no text."
    ),
    "ai_icon_C.png": (
        f"A premium iOS app icon. Neumorphic soft-UI design. "
        "A bold DL monogram — large uppercase letter D on the left, "
        "uppercase letter L on the right — in a clean geometric sans-serif. "
        f"Set on a {PALETTE}. "
        "Both letters are the same pale gray as the background; their shape is "
        "revealed only by soft neumorphic dual shadows that make them look "
        "three-dimensionally raised from the surface. No fill colour. "
        "Minimal, elegant, no other text."
    ),
    "ai_icon_D.png": (
        f"A premium iOS app icon. Neumorphic design. "
        "A bold DL monogram — large uppercase D in deep charcoal (#2D2D3E) "
        "and large uppercase L in matte red (#CC2D2D) — "
        "clean geometric sans-serif letterforms, "
        f"placed on a {PALETTE}. "
        "Soft neumorphic shadows surround each letter, adding tactile 3-D depth. "
        "Bold yet refined. No other text or decoration."
    ),
}


def generate(client, prompt, out_path):
    resp = client.models.generate_images(
        model=MODEL,
        prompt=prompt,
        config=types.GenerateImagesConfig(
            number_of_images=1,
            aspect_ratio="1:1",
            output_mime_type="image/png",
        ),
    )
    if not resp.generated_images:
        print(f"  ✗ no image returned for {os.path.basename(out_path)}")
        return

    raw = resp.generated_images[0].image.image_bytes

    # Resize to exactly 1024×1024, convert to RGB (no alpha)
    img = Image.open(io.BytesIO(raw)).convert("RGB").resize((1024, 1024), Image.LANCZOS)
    img.save(out_path, "PNG")
    print(f"  ✓ {os.path.basename(out_path)}")


def main():
    client = genai.Client(api_key=API_KEY)
    print(f"Generating {len(PROMPTS)} icons with {MODEL}...\n")
    for fname, prompt in PROMPTS.items():
        out = os.path.join(OUTDIR, fname)
        print(f"→ {fname}")
        try:
            generate(client, prompt, out)
        except Exception as e:
            print(f"  ✗ error: {e}")
    print("\nDone.")


if __name__ == "__main__":
    main()
