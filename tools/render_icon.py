"""Render the Digg "d" path from digg-logo.svg into the app icon PNGs.

We rasterize manually because cairosvg/svglib both need libcairo (unavailable
on this Windows machine), and svgexport silently failed. Pillow ships with
everything we need: ImageDraw.polygon for the outer letterform, then a
second polygon filled with the background color to carve the bowl out
(SVG uses fill-rule:nonzero by default and the digg path self-intersects
to define the hole — easier for us to render outer + inner separately
than to wire up a fill-rule-aware rasterizer).

Outputs four PNGs:
    assets/icon/icon-source.png         1024×1024  green BG, black D
    assets/icon/icon-foreground.png     1024×1024  transparent BG, white D (Android adaptive)
    android/app/src/main/res/drawable/ic_notification.png  96×96  transparent BG, white silhouette
"""

from pathlib import Path
from PIL import Image, ImageDraw
from svg.path import parse_path, CubicBezier, Line, Move, Close

ROOT = Path(__file__).resolve().parent.parent

# First path of digg-logo.svg — the "d" glyph, viewBox 0..80 × 0..80.
DIGG_D_PATH = (
    "M57 0C58.66 0 60 1.34 60 3V13C60 14.66 61.34 16 63 16H77C78.66 16 80 17.34 80 19V61"
    "C80 62.66 78.66 64 77 64H63C61.34 64 60 65.34 60 67V77C60 78.66 58.66 80 57 80H3"
    "C1.34 80 0 78.66 0 77V35C0 33.34 1.34 32 3 32H17C18.66 32 20 33.34 20 35V60"
    "C20 62.21 21.79 64 24 64H57C58.66 64 60 62.66 60 61V19"
    "C60 17.34 58.66 16 57 16H3C1.34 16 0 14.66 0 13V3C0 1.34 1.34 0 3 0H57Z"
)


def sample_path(d, n_per_curve=24):
    """Walk an SVG path and return a flat list of (x, y) vertices ready to
    feed to PIL polygon. Cubic beziers are sampled at `n_per_curve` evenly
    spaced parameters."""
    path = parse_path(d)
    pts = []
    for seg in path:
        if isinstance(seg, Move):
            pts.append((seg.start.real, seg.start.imag))
        elif isinstance(seg, Line):
            pts.append((seg.end.real, seg.end.imag))
        elif isinstance(seg, CubicBezier):
            # Skip t=0 (we already have the previous segment's end).
            for i in range(1, n_per_curve + 1):
                t = i / n_per_curve
                pt = seg.point(t)
                pts.append((pt.real, pt.imag))
        elif isinstance(seg, Close):
            pass  # last point closes back to start; PIL polygon auto-closes
    return pts


def render_icon(size, out_path, bg, fg, padding_pct=0.16, corner_radius_pct=0.22):
    """Render the icon at `size`×`size`. bg/fg are RGBA tuples; bg with
    alpha=0 produces a transparent background."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded green tile (only when bg has any opacity).
    if bg[3] > 0:
        r = int(round(size * corner_radius_pct))
        draw.rounded_rectangle([(0, 0), (size, size)], radius=r, fill=bg)

    # Project the 80×80 path into a centered square at padding_pct from each edge.
    inset = int(round(size * padding_pct))
    target = size - 2 * inset
    scale = target / 80.0

    pts = sample_path(DIGG_D_PATH, n_per_curve=64)
    pts = [(inset + x * scale, inset + y * scale) for (x, y) in pts]

    # The digg path is one self-intersecting closed polygon — the inner
    # bowl is defined by the loop crossing back through itself. PIL's
    # polygon fill uses an even-odd scanline rule, which is exactly the
    # behaviour the SVG path was authored for, so we just feed every
    # sampled point in order and the bowl falls out automatically.
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)

    glyph = Image.new("RGBA", (size, size), fg)
    img.paste(glyph, mask=mask)

    img.save(out_path, "PNG")
    print(f"Wrote {out_path}")


def main():
    # Main app icon — black D on Digg green, rounded tile.
    render_icon(
        1024,
        ROOT / "assets/icon/icon-source.png",
        bg=(0x00, 0xBA, 0x7C, 0xFF),
        fg=(0, 0, 0, 0xFF),
        padding_pct=0.18,
    )
    # Android adaptive foreground — white D on transparent, larger safe zone.
    render_icon(
        1024,
        ROOT / "assets/icon/icon-foreground.png",
        bg=(0, 0, 0, 0),
        fg=(0xFF, 0xFF, 0xFF, 0xFF),
        padding_pct=0.28,
    )
    # Notification icon — white silhouette on transparent, small.
    render_icon(
        96,
        ROOT / "android/app/src/main/res/drawable/ic_notification.png",
        bg=(0, 0, 0, 0),
        fg=(0xFF, 0xFF, 0xFF, 0xFF),
        padding_pct=0.18,
        corner_radius_pct=0,
    )


if __name__ == "__main__":
    main()
