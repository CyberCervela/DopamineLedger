#!/usr/bin/env python3
"""
generate_app_icon.py
Creates the Dopamine Ledger neumorphic lightning bolt app icon.

Output: 1024×1024 PNG, no alpha channel, no pre-rounded corners.
(Apple applies the superellipse mask itself; never pre-round.)

Design notes:
  - Background and bolt share the exact NeuTheme background hue (#E8E8EE).
    Depth comes only from dual shadows — white highlight top-left,
    blue-gray shadow bottom-right — exactly matching how neumorphic
    cards look inside the app.
  - The bolt face carries a subtle diagonal gradient (lighter at top-left,
    slightly darker at bottom-right) so the silhouette stays legible at
    the 60×60 home-screen size.
  - All colour values are sourced from NeuTheme.swift — no new palette.
"""

from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import os

SIZE = 1024

# ── NeuTheme palette (NeuTheme.swift) ────────────────────────────────────────
BG = (232, 232, 238)           # background / surface: #E8E8EE

# Bolt face gradient: top-left "lit" corner → bottom-right "shadow" corner.
# Both are tiny shifts from BG — still reads as the same surface.
BOLT_LIT    = (248, 248, 253)  # slightly lighter than BG (highlight side)
BOLT_SHADOW = (210, 210, 220)  # slightly darker  than BG (shadow side)

# NeuTheme shadowDark: Color(red:0.660, green:0.660, blue:0.720).opacity(0.60)
DARK_RGB   = (168, 168, 184)
DARK_ALPHA = int(255 * 0.62)   # bumped a touch from 0.60 for icon legibility

# NeuTheme shadowLight: Color.white.opacity(0.90)
LIGHT_RGB   = (255, 255, 255)
LIGHT_ALPHA = int(255 * 0.92)  # bumped a touch from 0.90

# Shadow geometry — larger than UI values to read at 60px home-screen size
SHADOW_OFFSET = 28   # px the shadow layer is shifted
SHADOW_BLUR   = 36   # GaussianBlur radius


# ── Lightning bolt polygon ────────────────────────────────────────────────────

def bolt_points(cx: int, cy: int, w: int, h: int) -> list[tuple[int, int]]:
    """
    Returns the 8 vertices of a classic lightning bolt centred at (cx, cy).

    Outline (clockwise from top-left):
        p1 → p2  top edge
        p2 → p3  upper-right diagonal going down-left
        p3 → p4  middle kink: horizontal jut to the right  ← the bolt "notch"
        p4 → p5  lower-right diagonal going down-left
        p5 → p6  bottom edge (tip on left)
        p6 → p7  lower-left diagonal going up-right
        p7 → p8  middle kink: horizontal jut back to the left
        p8 → p1  upper-left diagonal going up-right
    """
    x0, y0 = cx - w // 2, cy - h // 2

    def p(rx: float, ry: float) -> tuple[int, int]:
        return (round(x0 + rx * w), round(y0 + ry * h))

    return [
        p(0.32, 0.00),   # p1 top-left
        p(0.80, 0.00),   # p2 top-right
        p(0.56, 0.46),   # p3 upper-right, at kink height
        p(0.76, 0.46),   # p4 outer kink corner
        p(0.64, 1.00),   # p5 bottom-right
        p(0.20, 1.00),   # p6 bottom-left (the lightning "tip")
        p(0.44, 0.54),   # p7 inner kink, left edge
        p(0.24, 0.54),   # p8 inner kink corner
    ]


# ── Rendering helpers ─────────────────────────────────────────────────────────

def shadow_layer(
    pts: list[tuple[int, int]],
    color_rgb: tuple[int, int, int],
    alpha: int,
    offset_x: int,
    offset_y: int,
    blur: float,
) -> Image.Image:
    """Draw a filled polygon, shift it, then blur it."""
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(pts, fill=(*color_rgb, alpha))

    shifted = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    # PIL.paste clips automatically — negative offsets are fine
    shifted.paste(layer, (offset_x, offset_y))
    return shifted.filter(ImageFilter.GaussianBlur(radius=blur))


def bolt_gradient_layer(pts: list[tuple[int, int]]) -> Image.Image:
    """
    Diagonal gradient (top-left = BOLT_LIT, bottom-right = BOLT_SHADOW),
    masked to the bolt polygon shape.
    """
    x = np.linspace(0.0, 1.0, SIZE, dtype=np.float32)
    y = np.linspace(0.0, 1.0, SIZE, dtype=np.float32)
    xx, yy = np.meshgrid(x, y)

    # t = 1.0 at (0, 0), t = 0.0 at (1, 1)
    t = np.clip(1.0 - (xx + yy) * 0.5, 0.0, 1.0)

    def lerp(a: int, b: int) -> np.ndarray:
        return (a * t + b * (1.0 - t)).clip(0, 255).astype(np.uint8)

    r = lerp(BOLT_LIT[0], BOLT_SHADOW[0])
    g = lerp(BOLT_LIT[1], BOLT_SHADOW[1])
    b = lerp(BOLT_LIT[2], BOLT_SHADOW[2])
    a = np.full((SIZE, SIZE), 255, dtype=np.uint8)

    grad = Image.fromarray(np.stack([r, g, b, a], axis=-1), mode="RGBA")

    # Mask: white = opaque inside bolt, black = transparent outside
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)

    result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    result.paste(grad, mask=mask)
    return result


# ── Main ──────────────────────────────────────────────────────────────────────

def generate() -> Image.Image:
    # Solid background
    canvas = Image.new("RGBA", (SIZE, SIZE), (*BG, 255))

    # Bolt geometry: 62% wide, 79% tall, centred
    w = round(SIZE * 0.62)
    h = round(SIZE * 0.79)
    pts = bolt_points(SIZE // 2, SIZE // 2, w, h)

    # 1. Dark shadow — shifted bottom-right, simulates depth / raised surface
    dark = shadow_layer(pts, DARK_RGB, DARK_ALPHA, SHADOW_OFFSET, SHADOW_OFFSET, SHADOW_BLUR)
    canvas = Image.alpha_composite(canvas, dark)

    # 2. Light highlight — shifted top-left, simulates the "lamp" above the surface
    light = shadow_layer(pts, LIGHT_RGB, LIGHT_ALPHA, -SHADOW_OFFSET, -SHADOW_OFFSET, SHADOW_BLUR)
    canvas = Image.alpha_composite(canvas, light)

    # 3. Bolt fill — gradient, no offset; covers the shadow bleed in the centre
    fill = bolt_gradient_layer(pts)
    canvas = Image.alpha_composite(canvas, fill)

    # Apple requires no alpha channel in icon PNGs
    return canvas.convert("RGB")


if __name__ == "__main__":
    icon = generate()

    out = os.path.join(
        os.path.dirname(__file__),
        "..",
        "DopamineLedger",
        "Assets.xcassets",
        "AppIcon.appiconset",
        "AppIcon-1024.png",
    )
    out = os.path.normpath(out)
    icon.save(out, "PNG")
    print(f"Saved {SIZE}×{SIZE} icon → {out}")
