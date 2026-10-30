"""Ethiopian-friendly phone normalization to E.164."""

from __future__ import annotations

import re


_DIGITS = re.compile(r"\D+")


def normalize_phone(raw: str) -> str:
    """Normalize a phone number to E.164.

    Accepts common Ethiopian forms (``09…``, ``07…``, ``9…``, ``251…``) and
    already-international ``+…`` numbers. Raises ``ValueError`` when the input
    cannot be normalized to a plausible E.164 value.
    """
    s = (raw or "").strip()
    if not s:
        raise ValueError("Phone number is required.")

    if s.startswith("+"):
        digits = _DIGITS.sub("", s[1:])
        if not digits or len(digits) < 8 or len(digits) > 15:
            raise ValueError("Invalid phone number.")
        return f"+{digits}"

    digits = _DIGITS.sub("", s)
    if not digits:
        raise ValueError("Invalid phone number.")

    # Ethiopia local → +251
    if digits.startswith("0") and len(digits) == 10 and digits[1] in "97":
        return f"+251{digits[1:]}"
    if len(digits) == 9 and digits[0] in "97":
        return f"+251{digits}"
    if digits.startswith("251") and len(digits) == 12:
        return f"+{digits}"

    if 8 <= len(digits) <= 15:
        return f"+{digits}"

    raise ValueError("Invalid phone number.")


def mask_phone(phone: str) -> str:
    """Return a log-safe masked form of an E.164 phone."""
    if len(phone) <= 6:
        return "***"
    return f"{phone[:4]}***{phone[-2:]}"
