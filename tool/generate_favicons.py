"""
Generate Momentō favicon + PWA icon set from the wordmark.

The wordmark renders well at ≥192 px (PWA install icons, OS launcher)
but is unreadable at 32×32 in a browser tab. So:

- web/favicon.png (32×32):       Ō glyph only.  ← brand's distinctive feature
- web/favicon-32.png (32×32):    Ō glyph (alias for crawlers).
- web/favicon.svg:               full wordmark (modern browsers scale it).
- web/icons/Icon-192.png:        wordmark, white background, 5 % padding.
- web/icons/Icon-512.png:        same as 192 but 512.
- web/icons/Icon-maskable-*.png: wordmark inside a 60 %-of-canvas safe area
                                 so Android's circle / squircle mask doesn't
                                 clip the letters.

Run from repo root:  python tool/generate_favicons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT = Path("tool/fonts/JosefinSans-Light.ttf")
WORDMARK = "MOMENTŌ"
GLYPH = "Ō"
INK = (26, 26, 26, 255)         # AppColors.primaryText (#1A1A1A)
BG = (255, 255, 255, 255)       # AppColors.background  (white)

OUT_DIR = Path("web")
ICONS_DIR = OUT_DIR / "icons"
ICONS_DIR.mkdir(parents=True, exist_ok=True)


def _fit_text(text: str, target_w: int, target_h: int, *, tracking: float) -> ImageFont.FreeTypeFont:
    """Binary-search the largest font size whose tracked text fits in box."""
    lo, hi = 8, max(target_w, target_h) * 2
    best = None
    while lo <= hi:
        mid = (lo + hi) // 2
        f = ImageFont.truetype(str(FONT), mid)
        # Sum advance widths individually so we can apply letter-spacing.
        advances = [f.getbbox(c)[2] - f.getbbox(c)[0] for c in text]
        spaced_w = sum(advances) + int(mid * tracking) * (len(text) - 1)
        bbox = f.getbbox(text)
        h = bbox[3] - bbox[1]
        if spaced_w <= target_w and h <= target_h:
            best = f
            lo = mid + 1
        else:
            hi = mid - 1
    assert best, "couldn't fit any font size"
    return best


def _draw_tracked(canvas: Image.Image, text: str, font: ImageFont.FreeTypeFont,
                  *, tracking: float) -> None:
    """Draw `text` centered with letter-spacing == font_size * tracking."""
    draw = ImageDraw.Draw(canvas)
    w, h = canvas.size
    advances = [font.getbbox(c)[2] - font.getbbox(c)[0] for c in text]
    track_px = int(font.size * tracking)
    total = sum(advances) + track_px * (len(text) - 1)
    bbox = font.getbbox(text)
    th = bbox[3] - bbox[1]
    # Vertical baseline correction — bbox[1] is negative (top above baseline).
    x = (w - total) // 2
    y = (h - th) // 2 - bbox[1]
    for i, ch in enumerate(text):
        draw.text((x, y), ch, fill=INK, font=font)
        x += advances[i] + track_px


def render_glyph(size: int) -> Image.Image:
    """Single Ō glyph filling ~70 % of canvas."""
    img = Image.new("RGBA", (size, size), BG)
    f = _fit_text(GLYPH, int(size * 0.72), int(size * 0.72), tracking=0)
    _draw_tracked(img, GLYPH, f, tracking=0)
    return img


def render_wordmark(size: int, *, safe_pct: float = 0.10) -> Image.Image:
    """Full wordmark, centered, with `safe_pct` padding on each side.

    `safe_pct=0.10` for normal icons (5 % visual padding feels right; we use
    10 % bbox padding because the font has built-in side-bearings).
    `safe_pct=0.20` for maskable icons (Android shaves ~20 % off the edges).
    """
    img = Image.new("RGBA", (size, size), BG)
    inset = int(size * safe_pct)
    target = size - inset * 2
    # Brand letter-spacing = 4.5/18 ≈ 0.25 (per momento_logo.dart).
    f = _fit_text(WORDMARK, target, int(target * 0.45), tracking=0.25)
    _draw_tracked(img, WORDMARK, f, tracking=0.25)
    return img


# ── browser-tab favicon ──────────────────────────────────────────────────
fav32 = render_glyph(32)
fav32.save(OUT_DIR / "favicon.png", optimize=True)

# ── PWA install icons (display at full size) ─────────────────────────────
render_wordmark(192).save(ICONS_DIR / "Icon-192.png", optimize=True)
render_wordmark(512).save(ICONS_DIR / "Icon-512.png", optimize=True)

# ── maskable variants — wider safe-area so Android mask doesn't clip ─────
render_wordmark(192, safe_pct=0.20).save(
    ICONS_DIR / "Icon-maskable-192.png", optimize=True)
render_wordmark(512, safe_pct=0.20).save(
    ICONS_DIR / "Icon-maskable-512.png", optimize=True)

# ── SVG favicon — modern browsers prefer this; scales perfectly ──────────
# Inline the wordmark as <text> rather than embedding glyph paths so the
# file stays tiny + editable. We rely on the browser to fall back to a
# system sans if Josefin Sans isn't available — close enough at favicon
# scale; the PNG fallback above covers everything else.
svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <rect width="256" height="256" fill="#FFFFFF"/>
  <text x="128" y="148" text-anchor="middle"
        font-family="'Josefin Sans', 'Segoe UI', system-ui, sans-serif"
        font-weight="300" font-size="44" letter-spacing="11"
        fill="#1A1A1A">MOMENTŌ</text>
</svg>
"""
(OUT_DIR / "favicon.svg").write_text(svg, encoding="utf-8")

print("Generated:")
for p in [
    OUT_DIR / "favicon.png",
    OUT_DIR / "favicon.svg",
    ICONS_DIR / "Icon-192.png",
    ICONS_DIR / "Icon-512.png",
    ICONS_DIR / "Icon-maskable-192.png",
    ICONS_DIR / "Icon-maskable-512.png",
]:
    print(f"  {p}  ({p.stat().st_size:,} bytes)")
