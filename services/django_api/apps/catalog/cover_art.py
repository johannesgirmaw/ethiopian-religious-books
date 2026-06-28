"""Generate book cover PNGs (gradient + title) for seeding and backfill."""

from __future__ import annotations

import io
import uuid
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from apps.catalog.models import Book
from apps.catalog.storage_s3 import is_object_storage_configured, put_bytes

_WIDTH = 600
_HEIGHT = 900

# Matches Flutter `catalogBookGradient` in catalog_book_visuals.dart.
_CYAN = ((0x14, 0x70, 0x8F), (0x29, 0xB6, 0xE0), (0x5C, 0xCD, 0xEC))
_DEEP = ((0x0A, 0x3A, 0x4A), (0x1E, 0x9B, 0xC2), (0x14, 0x70, 0x8F))

_FONT_DIR = Path(__file__).resolve().parent / "assets" / "fonts"

_SYSTEM_FONTS = (
    "/usr/share/fonts/truetype/noto/NotoSansEthiopic-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansEthiopic-Regular.ttf",
    "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
    "/usr/share/fonts/opentype/noto/NotoSans-Regular.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/Library/Fonts/Arial Unicode.ttf",
)


def _lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _gradient_colors(index: int) -> tuple[tuple[int, int, int], ...]:
    return _CYAN if index % 2 == 0 else _DEEP


def _gradient_image(index: int) -> Image.Image:
    colors = _gradient_colors(index)
    img = Image.new("RGB", (_WIDTH, _HEIGHT))
    draw = ImageDraw.Draw(img)
    for y in range(_HEIGHT):
        t = y / max(_HEIGHT - 1, 1)
        if t <= 0.55:
            c = _lerp(colors[0], colors[1], t / 0.55)
        else:
            c = _lerp(colors[1], colors[2], (t - 0.55) / 0.45)
        draw.line([(0, y), (_WIDTH, y)], fill=c)
    return img


def _has_ethiopic(text: str) -> bool:
    return any("\u1200" <= ch <= "\u137f" for ch in text)


def _font_candidates(prefer_ethiopic: bool) -> list[Path]:
    bundled = [
        _FONT_DIR / "NotoSansEthiopic-Regular.ttf",
        _FONT_DIR / "NotoSans-Regular.ttf",
    ]
    system = [Path(p) for p in _SYSTEM_FONTS]
    if prefer_ethiopic:
        return bundled + system
    return bundled[1:] + bundled[:1] + system


def _load_font(size: int, *, prefer_ethiopic: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in _font_candidates(prefer_ethiopic):
        if path.is_file():
            try:
                return ImageFont.truetype(str(path), size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def _text_width(font: ImageFont.FreeTypeFont | ImageFont.ImageFont, text: str) -> float:
    if hasattr(font, "getlength"):
        return float(font.getlength(text))
    bbox = font.getbbox(text)
    return float(bbox[2] - bbox[0])


def _wrap_text(text: str, font: ImageFont.FreeTypeFont | ImageFont.ImageFont, max_width: int) -> list[str]:
    words = text.split()
    if not words:
        return []
    lines: list[str] = []
    current = words[0]
    for word in words[1:]:
        trial = f"{current} {word}"
        if _text_width(font, trial) <= max_width:
            current = trial
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def _draw_watermark(draw: ImageDraw.ImageDraw) -> None:
    cx, cy, r = _WIDTH * 0.72, _HEIGHT * 0.22, 72
    stroke = (255, 255, 255)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=stroke, width=2)
    draw.line((cx, cy - r, cx, cy + r), fill=stroke, width=2)
    draw.line((cx - r, cy, cx + r, cy), fill=stroke, width=2)
    d = r * 0.65
    draw.line((cx - d, cy - d, cx + d, cy + d), fill=stroke, width=2)
    draw.line((cx + d, cy - d, cx - d, cy + d), fill=stroke, width=2)


def _draw_wrapped(
    draw: ImageDraw.ImageDraw,
    text: str,
    *,
    font: ImageFont.FreeTypeFont | ImageFont.ImageFont,
    x: int,
    y: int,
    max_width: int,
    fill: tuple[int, int, int],
    line_gap: int,
) -> int:
    lines = _wrap_text(text.strip(), font, max_width)
    cursor = y
    for line in lines:
        draw.text((x, cursor), line, font=font, fill=fill)
        bbox = font.getbbox(line or "Ay")
        cursor += (bbox[3] - bbox[1]) + line_gap
    return cursor


def render_cover_png(
    title: str,
    *,
    subtitle: str = "",
    author: str = "",
    index: int = 0,
) -> bytes:
    """Return PNG bytes for a book cover card."""
    img = _gradient_image(index)
    draw = ImageDraw.Draw(img)
    _draw_watermark(draw)

    combined = f"{title} {subtitle} {author}"
    ethiopic = _has_ethiopic(combined)
    title_font = _load_font(44 if len(title) < 24 else 36, prefer_ethiopic=ethiopic)
    meta_font = _load_font(24, prefer_ethiopic=ethiopic)

    margin = 48
    max_width = _WIDTH - margin * 2
    y = _HEIGHT - margin

    if author.strip():
        author_lines = _wrap_text(author.strip(), meta_font, max_width)
        for line in reversed(author_lines):
            bbox = meta_font.getbbox(line or "Ay")
            line_h = bbox[3] - bbox[1]
            y -= line_h
            draw.text((margin, y), line, font=meta_font, fill=(230, 245, 250))
            y -= 8
        y -= 12

    if subtitle.strip():
        y = _draw_wrapped(
            draw,
            subtitle.strip(),
            font=meta_font,
            x=margin,
            y=y - 80,
            max_width=max_width,
            fill=(240, 248, 252),
            line_gap=6,
        )
        y -= 16

    _draw_wrapped(
        draw,
        title.strip() or "Untitled",
        font=title_font,
        x=margin,
        y=max(120, y - 160),
        max_width=max_width,
        fill=(255, 255, 255),
        line_gap=8,
    )

    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def assign_cover_for_book(book: Book, *, index: int = 0, force: bool = False) -> bool:
    """Upload a generated cover and persist ``cover_object_key``. Returns True when updated."""
    if not is_object_storage_configured():
        return False
    if (book.cover_object_key or "").strip() and not force:
        return False

    png = render_cover_png(
        book.title,
        subtitle=book.subtitle or "",
        author=book.author_compiler or "",
        index=index,
    )
    object_key = f"books/{book.id}/covers/{uuid.uuid4()}.png"
    put_bytes(object_key, png, "image/png")
    book.cover_object_key = object_key
    book.save(update_fields=["cover_object_key", "updated_at"])
    return True
