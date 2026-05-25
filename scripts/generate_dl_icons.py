#!/usr/bin/env python3
"""
generate_dl_icons.py
Three neumorphic "DL" monogram app icon variants for Dopamine Ledger.

Variant 1 — AppIcon-DL-v1-neutral.png
    "DL" side by side, both letters raised from the NeuTheme background.
    Neutral palette: same hue as background, depth from dual shadows only.

Variant 2 — AppIcon-DL-v2-monogram.png
    Merged DL monogram. The D and L share a single vertical bar:
    the D's curve bows right on the upper half, the L's foot extends
    right on the lower half. A single cohesive mark instead of two letters.
    Also raised, also neutral.

Variant 3 — AppIcon-DL-v3-color.png
    "DL" side by side, same layout as V1 but D filled with charcoal
    (#2D2D3E) and L filled with matte red (#CC2D2D) — both NeuTheme
    accent colours — while the neumorphic dual shadows remain.

All outputs: 1024×1024 PNG, RGB (no alpha), no pre-rounded corners.
"""

from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import math, os

SIZE = 1024

# ── NeuTheme palette (from NeuTheme.swift) ───────────────────────────────────
BG          = (232, 232, 238)        # background / surface  #E8E8EE
DARK_RGB    = (168, 168, 184)        # shadowDark base
DARK_ALPHA  = int(255 * 0.65)        # slightly boosted from 0.60 for icon legibility
LIGHT_RGB   = (255, 255, 255)        # shadowLight = white
LIGHT_ALPHA = int(255 * 0.95)        # slightly boosted from 0.90

ACCENT_CHARCOAL = (46,  46,  62)     # colors.accent  #2D2D3E
ACCENT_RED      = (204, 46,  46)     # colors.negative #CC2D2D

# Face gradient for neutral variants (top-left lit, bottom-right in shadow)
FACE_LIT    = (252, 252, 255)
FACE_SHADOW = (204, 204, 216)

# Shadow geometry — same as the lightning bolt icon
OFFSET = 26
BLUR   = 36

OUTDIR = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..",
                 "DopamineLedger", "Assets.xcassets", "AppIcon.appiconset")
)


# ── Letter polygon builders ───────────────────────────────────────────────────

def d_polygon(x0: int, y0: int, w: int, h: int, sw: int) -> list:
    """
    Solid bold 'D' as a closed polygon.
    The left bar (width=sw) connects to a right-half ellipse spanning
    the full height. Traced clockwise.
    """
    cx  = x0 + sw          # x-anchor for the curved right side
    cy  = y0 + h / 2       # vertical centre of the ellipse
    rx  = w - sw            # horizontal radius of the curve
    ry  = h / 2             # vertical radius
    n   = 48                # segments → smooth curve

    # Right half of ellipse: angle sweeps from -π/2 (top) to +π/2 (bottom)
    curve = [
        (round(cx + rx * math.cos(math.pi * (-0.5 + i / n))),
         round(cy + ry * math.sin(math.pi * (-0.5 + i / n))))
        for i in range(n + 1)
    ]
    return (
        [(x0, y0), (cx, y0)]   # top edge of left bar
        + curve                 # the right curve, top → bottom
        + [(cx, y0 + h), (x0, y0 + h)]  # bottom edge back left
    )


def l_polygon(x0: int, y0: int, w: int, h: int, sw: int, fh: int) -> list:
    """
    Solid bold 'L' as a closed polygon.
    sw = vertical stroke width; fh = foot height.
    """
    return [
        (x0,      y0),
        (x0 + sw, y0),
        (x0 + sw, y0 + h - fh),   # bottom of vertical stroke
        (x0 + w,  y0 + h - fh),   # top of foot (right end)
        (x0 + w,  y0 + h),        # foot bottom-right
        (x0,      y0 + h),        # foot bottom-left
    ]


def dl_merged_polygon(x0: int, y0: int, w: int, h: int,
                      sw: int, d_frac: float, fh: int) -> list:
    """
    Merged DL monogram. The D and L share a single vertical bar.

    Layout:
      · Shared vertical bar: (x0, y0) → (x0+sw, y0+h)
      · D's curve: right half of ellipse spanning the upper (d_frac × h) portion
      · L's foot:  horizontal bar at the bottom, extending to x0+w

    d_frac ∈ (0,1): fraction of height the D occupies (e.g. 0.56).
    fh: foot height of the L.
    """
    d_height = round(h * d_frac)

    # D curve parameters
    d_cx = x0 + sw              # curve anchors at the right edge of the bar
    d_cy = y0 + d_height / 2
    d_rx = w - sw               # D curve extends all the way to x0+w
    d_ry = d_height / 2
    n = 48

    d_curve = [
        (round(d_cx + d_rx * math.cos(math.pi * (-0.5 + i / n))),
         round(d_cy + d_ry * math.sin(math.pi * (-0.5 + i / n))))
        for i in range(n + 1)
    ]
    # d_curve[0]  = (d_cx, y0)          ← top of curve (connects to bar top-right)
    # d_curve[-1] = (d_cx, y0+d_height) ← bottom of curve (bar continues down)

    return (
        [(x0, y0), (d_cx, y0)]                     # bar top, then D curve starts
        + d_curve                                    # D's arc
        + [
            (x0 + sw, y0 + h - fh),                # bar's right edge reaches L foot
            (x0 + w,  y0 + h - fh),                # L foot top-right
            (x0 + w,  y0 + h),                     # L foot bottom-right
            (x0,      y0 + h),                     # bottom-left of bar
        ]
    )


# ── Compositing helpers ───────────────────────────────────────────────────────

def shadow_layer(pts: list, color: tuple, alpha: int,
                 dx: int, dy: int, blur: float) -> Image.Image:
    """Filled polygon, shifted by (dx,dy), then Gaussian-blurred."""
    layer   = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shifted = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(pts, fill=(*color, alpha))
    shifted.paste(layer, (dx, dy))
    return shifted.filter(ImageFilter.GaussianBlur(radius=blur))


def gradient_fill(pts: list, lit: tuple, shadow: tuple) -> Image.Image:
    """
    Diagonal gradient (top-left = lit, bottom-right = shadow),
    masked to the given polygon.
    """
    x  = np.linspace(0.0, 1.0, SIZE, dtype=np.float32)
    y  = np.linspace(0.0, 1.0, SIZE, dtype=np.float32)
    xx, yy = np.meshgrid(x, y)
    t  = np.clip(1.0 - (xx + yy) * 0.5, 0.0, 1.0)

    r  = (lit[0] * t + shadow[0] * (1 - t)).astype(np.uint8)
    g  = (lit[1] * t + shadow[1] * (1 - t)).astype(np.uint8)
    b  = (lit[2] * t + shadow[2] * (1 - t)).astype(np.uint8)
    a  = np.full((SIZE, SIZE), 255, dtype=np.uint8)

    grad = Image.fromarray(np.stack([r, g, b, a], axis=-1))
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    result.paste(grad, mask=mask)
    return result


def solid_fill(pts: list, color: tuple) -> Image.Image:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(pts, fill=(*color, 255))
    return layer


def apply_raised(canvas: Image.Image, shapes: list, fills) -> Image.Image:
    """
    Composite neumorphic 'raised' effect onto canvas.
    shapes: list of polygon point-lists.
    fills:  list of (lit_color, shadow_color) tuples OR solid (R,G,B) tuples.
            Pass None entries to use the default neutral gradient.
    """
    # 1. All dark shadows first (bottom-right)
    for pts in shapes:
        canvas = Image.alpha_composite(
            canvas, shadow_layer(pts, DARK_RGB, DARK_ALPHA, OFFSET, OFFSET, BLUR)
        )
    # 2. All light highlights (top-left)
    for pts in shapes:
        canvas = Image.alpha_composite(
            canvas, shadow_layer(pts, LIGHT_RGB, LIGHT_ALPHA, -OFFSET, -OFFSET, BLUR)
        )
    # 3. Fills (cover the shadow bleed in the shape's own footprint)
    for pts, fill in zip(shapes, fills):
        if isinstance(fill, tuple) and len(fill) == 3 and isinstance(fill[0], int):
            # Solid colour
            canvas = Image.alpha_composite(canvas, solid_fill(pts, fill))
        else:
            # (lit, shadow) gradient pair
            canvas = Image.alpha_composite(
                canvas, gradient_fill(pts, fill[0], fill[1])
            )
    return canvas


# ── Variant generators ────────────────────────────────────────────────────────

def variant_1_neutral(d_pts, l_pts) -> Image.Image:
    """V1: DL side-by-side, raised, neutral gradient faces."""
    canvas = Image.new("RGBA", (SIZE, SIZE), (*BG, 255))
    neutral = (FACE_LIT, FACE_SHADOW)
    canvas = apply_raised(canvas, [d_pts, l_pts], [neutral, neutral])
    return canvas.convert("RGB")


def variant_2_monogram(mono_pts) -> Image.Image:
    """V2: Merged DL monogram, raised, neutral gradient face."""
    canvas = Image.new("RGBA", (SIZE, SIZE), (*BG, 255))
    canvas = apply_raised(canvas, [mono_pts], [(FACE_LIT, FACE_SHADOW)])
    return canvas.convert("RGB")


def variant_3_color(d_pts, l_pts) -> Image.Image:
    """V3: DL side-by-side, raised, D=charcoal, L=red."""
    canvas = Image.new("RGBA", (SIZE, SIZE), (*BG, 255))
    canvas = apply_raised(canvas, [d_pts, l_pts], [ACCENT_CHARCOAL, ACCENT_RED])
    return canvas.convert("RGB")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    # ── V1 & V3: side-by-side D and L ────────────────────────────────────────
    lh    = 510    # letter height
    d_w   = 262    # D bounding-box width
    l_w   = 240    # L bounding-box width
    sw    = 82     # stroke width (bar thickness)
    fh    = 82     # L foot height
    gap   = 72     # gap between the two letters

    total_w = d_w + gap + l_w          # 574
    x0 = (SIZE - total_w) // 2         # 225
    y0 = (SIZE - lh) // 2              # 257

    d_pts = d_polygon(x0,            y0, d_w, lh, sw)
    l_pts = l_polygon(x0 + d_w + gap, y0, l_w, lh, sw, fh)

    # ── V2: merged monogram ───────────────────────────────────────────────────
    # The monogram's bounding box matches D's width so the two variants
    # have the same visual weight when compared side-by-side.
    mono_w  = 318   # total width (bar + D/L foot extent)
    mono_h  = 560   # taller than the side-by-side to fill the canvas better
    mono_sw = 90    # thicker bar — the single vertical stroke carries both letters
    mono_fh = 88    # L foot height

    mx0 = (SIZE - mono_w) // 2   # 353
    my0 = (SIZE - mono_h) // 2   # 232

    mono_pts = dl_merged_polygon(mx0, my0, mono_w, mono_h,
                                 mono_sw, d_frac=0.55, fh=mono_fh)

    # ── Save all three ────────────────────────────────────────────────────────
    variants = [
        ("AppIcon-DL-v1-neutral.png",  variant_1_neutral(d_pts, l_pts)),
        ("AppIcon-DL-v2-monogram.png", variant_2_monogram(mono_pts)),
        ("AppIcon-DL-v3-color.png",    variant_3_color(d_pts, l_pts)),
    ]

    for fname, img in variants:
        path = os.path.join(OUTDIR, fname)
        img.save(path, "PNG")
        print(f"Saved {SIZE}×{SIZE} → {path}")


if __name__ == "__main__":
    main()
