import re

_PUNCT_RE = re.compile(r"[^\w\s\u1200-\u137F]+", re.UNICODE)
_SPACE_RE = re.compile(r"\s+")

# Common Ge'ez/Amharic glyph variants to reduce false negatives.
_VARIANT_MAP = str.maketrans(
    {
        "ሃ": "ሀ",
        "ኃ": "ሀ",
        "ሐ": "ሀ",
        "ሓ": "ሀ",
        "ኻ": "ካ",
        "ሠ": "ሰ",
        "ጸ": "ፀ",
        "ጹ": "ፁ",
        "ጺ": "ፂ",
        "ጻ": "ፃ",
        "ጼ": "ፄ",
        "ጽ": "ፅ",
        "ዐ": "አ",
        "ዑ": "ኡ",
        "ዒ": "ኢ",
        "ዓ": "ኣ",
        "ዔ": "ኤ",
        "ዕ": "እ",
        "ዖ": "ኦ",
    }
)


def normalize_search_text(value: str | None) -> str:
    if not value:
        return ""
    text = value.lower().translate(_VARIANT_MAP)
    text = _PUNCT_RE.sub(" ", text)
    return _SPACE_RE.sub(" ", text).strip()
