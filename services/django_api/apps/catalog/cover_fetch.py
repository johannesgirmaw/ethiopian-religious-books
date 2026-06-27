"""Download book cover images from public sources (Open Library, Wikimedia)."""

from __future__ import annotations

import json
import logging
import re
import urllib.error
import urllib.parse
import urllib.request
import uuid
from io import BytesIO

from PIL import Image

from apps.catalog.models import Book
from apps.catalog.storage_s3 import is_object_storage_configured, put_bytes

logger = logging.getLogger(__name__)

_USER_AGENT = "EthiopianReligiousBooks/1.0 (cover-fetch; +https://github.com/)"
_MIN_BYTES = 4_000
_MIN_SIDE = 120

# Amharic / local titles → English search terms for Open Library / Wikimedia.
_SEARCH_HINTS: dict[str, str] = {
    "መዝሙረ ዳዊት": "Book of Psalms",
    "ውዳሴ ማርያም": "Weddase Maryam Ethiopian",
    "ጸሎተ ሃይማኖት": "Nicene Creed Ethiopian",
    "አቡነ ዘበሰማያት": "Lord's Prayer Ge'ez",
    "ስንክሳር": "Synaxarium Ethiopian",
    "የዮሐንስ ወንጌል": "Gospel of John Ethiopic",
    "ድርሳነ ሚካኤል": "Dersane Michael Ethiopian",
    "ተአምረ ማርያም": "Miracles of Mary Ethiopian",
    "መጽሐፈ ሄኖክ": "Book of Enoch Ethiopic",
    "ፍትሐ ነገሥት": "Fetha Nagast",
    "መልክአ ኢየሱስ": "Ethiopian Orthodox prayer book",
    "ቅዳሴ ማርያም": "Qeddase Maryam",
    "አርጋኖን": "Arganona Mary Ethiopian",
    "ገድለ ተክለ ሃይማኖት": "Tekle Haymanot Ethiopian saint",
    "መጽሐፈ ቅዳሴ": "Ethiopian liturgy",
    "ጸሎተ ምሕላ": "Ethiopian penitential prayer",
    "የኢትዮጵያ ታሪክ": "History of Ethiopia",
    "የኢትዮጵያ ኦርቶዶክስ": "Ethiopian Orthodox Church history",
    "Sample Ethiopian religious text": "Ethiopian Orthodox manuscript",
}

_WIKI_FALLBACK_QUERIES = (
    "Ethiopian Orthodox manuscript",
    "Ge'ez manuscript bible",
    "Ethiopian religious book",
)

# Titles too vague for Open Library (matches unrelated bestsellers like "After").
_GENERIC_TITLE = re.compile(
    r"^(book\s*\d+|new\s+book|untitled|sample|test\s+book|placeholder)\s*$",
    re.I,
)


def _is_generic_title(title: str, subtitle: str) -> bool:
    t = (title or "").strip()
    if not t or _GENERIC_TITLE.match(t):
        return True
    if len(t.split()) <= 2 and t.lower().startswith("book "):
        return True
    if (subtitle or "").strip().lower() in ("new book", "placeholder", ""):
        return len(t) < 12
    return False


def _download(url: str, *, timeout: int = 25) -> bytes | None:
    req = urllib.request.Request(url, headers={"User-Agent": _USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read()
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        logger.debug("cover download failed for %s: %s", url, exc)
        return None


def _valid_cover(data: bytes | None) -> bool:
    if not data or len(data) < _MIN_BYTES:
        return False
    try:
        with Image.open(BytesIO(data)) as img:
            w, h = img.size
            return w >= _MIN_SIDE and h >= _MIN_SIDE
    except OSError:
        return False


def _search_hint(title: str, subtitle: str, author: str) -> str:
    combined = f"{title} {subtitle}".strip()
    for key, hint in _SEARCH_HINTS.items():
        if key in combined or key in title:
            return hint
    if re.search(r"[\u1200-\u137f]", title):
        if subtitle.strip():
            return subtitle.strip()
        if author.strip():
            return f"{author.strip()} Ethiopian"
        return "Ethiopian Orthodox religious book"
    return title.strip() or "religious book"


def _fetch_open_library(query: str) -> bytes | None:
    params = urllib.parse.urlencode({"q": query, "limit": "5", "fields": "cover_i,title"})
    url = f"https://openlibrary.org/search.json?{params}"
    raw = _download(url)
    if not raw:
        return None
    try:
        docs = json.loads(raw.decode("utf-8")).get("docs") or []
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None
    for doc in docs:
        cover_id = doc.get("cover_i")
        if not cover_id:
            continue
        img_url = f"https://covers.openlibrary.org/b/id/{cover_id}-L.jpg"
        data = _download(img_url)
        if _valid_cover(data):
            return data
    return None


def _fetch_wikimedia(query: str) -> bytes | None:
    params = urllib.parse.urlencode(
        {
            "action": "query",
            "format": "json",
            "generator": "search",
            "gsrsearch": f"{query} filetype:bitmap",
            "gsrlimit": "8",
            "prop": "imageinfo",
            "iiprop": "url",
            "iiurlwidth": "600",
        }
    )
    url = f"https://commons.wikimedia.org/w/api.php?{params}"
    raw = _download(url)
    if not raw:
        return None
    try:
        pages = json.loads(raw.decode("utf-8")).get("query", {}).get("pages") or {}
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None
    for page in pages.values():
        infos = page.get("imageinfo") or []
        for info in infos:
            img_url = info.get("thumburl") or info.get("url")
            if not img_url:
                continue
            data = _download(img_url)
            if _valid_cover(data):
                return data
    return None


def fetch_cover_bytes(title: str, *, subtitle: str = "", author: str = "") -> bytes | None:
    """Try public sources; return JPEG/PNG bytes or None."""
    query = _search_hint(title, subtitle, author)
    if not _is_generic_title(title, subtitle):
        data = _fetch_open_library(query)
        if data:
            return data
    data = _fetch_wikimedia(query)
    if data:
        return data
    for fallback in _WIKI_FALLBACK_QUERIES:
        data = _fetch_wikimedia(fallback)
        if data:
            return data
    return None


def _content_type_for(data: bytes) -> tuple[str, str]:
    if data.startswith(b"\xff\xd8"):
        return "image/jpeg", "jpg"
    if data.startswith(b"\x89PNG"):
        return "image/png", "png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp", "webp"
    return "image/jpeg", "jpg"


def assign_internet_cover_for_book(
    book: Book,
    *,
    force: bool = False,
    fallback_generator=None,
) -> bool:
    """Download a cover from the internet and store it. Returns True when updated."""
    if not is_object_storage_configured():
        return False
    if (book.cover_object_key or "").strip() and not force:
        return False

    data = fetch_cover_bytes(
        book.title,
        subtitle=book.subtitle or "",
        author=book.author_compiler or "",
    )
    if not data and fallback_generator is not None:
        data = fallback_generator(book)
    if not data:
        return False

    content_type, ext = _content_type_for(data)
    object_key = f"books/{book.id}/covers/{uuid.uuid4()}.{ext}"
    put_bytes(object_key, data, content_type)
    book.cover_object_key = object_key
    book.save(update_fields=["cover_object_key", "updated_at"])
    return True
