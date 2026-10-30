"""Telegram Bot API helpers for auth OTP and free notifications.

Uses the free Bot API only (no Gateway). Secrets stay server-side.
"""

from __future__ import annotations

import json
import logging
import urllib.error
import urllib.request
from typing import Any

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.accounts.models import TelegramAuthSession
from apps.accounts.phone import mask_phone, normalize_phone

logger = logging.getLogger(__name__)

_API_TIMEOUT_S = 10


class TelegramBotError(Exception):
    """Raised when the Bot API call fails or config is missing."""


def bot_configured() -> bool:
    return bool(
        getattr(settings, "TELEGRAM_AUTH_BOT_TOKEN", "")
        and getattr(settings, "TELEGRAM_AUTH_BOT_USERNAME", "")
    )


def webhook_secret() -> str:
    return getattr(settings, "TELEGRAM_AUTH_WEBHOOK_SECRET", "") or ""


def _api_base() -> str:
    token = getattr(settings, "TELEGRAM_AUTH_BOT_TOKEN", "") or ""
    if not token:
        raise TelegramBotError("TELEGRAM_AUTH_BOT_TOKEN is not configured.")
    return f"https://api.telegram.org/bot{token}"


def bot_api(method: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    """POST JSON to Telegram Bot API ``method``; return the parsed body."""
    url = f"{_api_base()}/{method}"
    data = json.dumps(payload or {}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=_API_TIMEOUT_S) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        logger.warning("Telegram API HTTP %s for %s: %s", exc.code, method, detail)
        raise TelegramBotError(f"Telegram API error ({exc.code})") from exc
    except Exception as exc:  # network / timeout
        logger.warning("Telegram API call failed for %s: %s", method, exc)
        raise TelegramBotError("Telegram API unreachable") from exc

    if not body.get("ok"):
        raise TelegramBotError(body.get("description") or "Telegram API rejected request")
    return body


def send_message(chat_id: int | str, text: str, *, reply_markup: dict | None = None) -> None:
    payload: dict[str, Any] = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML",
    }
    if reply_markup is not None:
        payload["reply_markup"] = reply_markup
    bot_api("sendMessage", payload)


def send_contact_request(chat_id: int | str) -> None:
    send_message(
        chat_id,
        "Share the phone number linked to this Telegram account to continue.",
        reply_markup={
            "keyboard": [
                [
                    {
                        "text": "Share Number & Get OTP",
                        "request_contact": True,
                    }
                ]
            ],
            "resize_keyboard": True,
            "one_time_keyboard": True,
        },
    )


def remove_keyboard(chat_id: int | str, text: str) -> None:
    send_message(
        chat_id,
        text,
        reply_markup={"remove_keyboard": True},
    )


def register_webhook() -> bool:
    """Register the auth bot webhook. Returns True on success / skip."""
    token = getattr(settings, "TELEGRAM_AUTH_BOT_TOKEN", "") or ""
    url = getattr(settings, "TELEGRAM_AUTH_WEBHOOK_URL", "") or ""
    if not token or not url:
        logger.info("Telegram auth webhook not registered (token/url unset).")
        return False
    secret = webhook_secret()
    if getattr(settings, "TELEGRAM_AUTH_REQUIRE_WEBHOOK_SECRET", True) and not secret:
        logger.error(
            "Refusing to register Telegram webhook without TELEGRAM_AUTH_WEBHOOK_SECRET."
        )
        return False
    body: dict[str, Any] = {
        "url": url,
        "allowed_updates": ["message"],
        "drop_pending_updates": True,
    }
    if secret:
        body["secret_token"] = secret
    try:
        bot_api("setWebhook", body)
        logger.info("Telegram auth webhook registered → %s", url)
        return True
    except TelegramBotError as exc:
        logger.error("Telegram webhook registration failed: %s", exc)
        return False


def initiate_session(
    *,
    raw_phone: str,
    purpose: str,
    user=None,
    ip: str | None = None,
) -> tuple[TelegramAuthSession, str]:
    """Create a deep-link session; returns (session, bot_link)."""
    if not bot_configured():
        raise TelegramBotError("Telegram auth is not configured.")

    phone = normalize_phone(raw_phone)
    if purpose not in {
        TelegramAuthSession.Purpose.LOGIN,
        TelegramAuthSession.Purpose.PHONE_LINK,
    }:
        raise ValueError("Invalid purpose.")

    if purpose == TelegramAuthSession.Purpose.PHONE_LINK and user is None:
        raise ValueError("phone_link requires an authenticated user.")

    now = timezone.now()
    # Per-phone initiate cooldown (anti-spam).
    recent = TelegramAuthSession.objects.filter(
        phone=phone,
        purpose=purpose,
        created_at__gte=now - TelegramAuthSession.INITIATE_COOLDOWN,
        consumed_at__isnull=True,
    ).exists()
    if recent:
        # Return the latest open session's link instead of creating spam rows.
        existing = (
            TelegramAuthSession.objects.filter(
                phone=phone,
                purpose=purpose,
                consumed_at__isnull=True,
                expires_at__gt=now,
            )
            .order_by("-created_at")
            .first()
        )
        if existing is not None:
            username = settings.TELEGRAM_AUTH_BOT_USERNAME.lstrip("@")
            return existing, f"https://t.me/{username}?start={existing.id}"

    # Expire prior open sessions for this phone+purpose.
    TelegramAuthSession.objects.filter(
        phone=phone,
        purpose=purpose,
        consumed_at__isnull=True,
    ).update(status=TelegramAuthSession.Status.EXPIRED, consumed_at=now)

    session = TelegramAuthSession.objects.create(
        phone=phone,
        purpose=purpose,
        user=user if purpose == TelegramAuthSession.Purpose.PHONE_LINK else None,
        expires_at=now + TelegramAuthSession.SESSION_TTL,
        requested_ip=ip,
    )
    username = settings.TELEGRAM_AUTH_BOT_USERNAME.lstrip("@")
    bot_link = f"https://t.me/{username}?start={session.id}"
    logger.info(
        "Telegram auth session %s created for %s (%s)",
        session.id,
        mask_phone(phone),
        purpose,
    )
    return session, bot_link


def handle_webhook_update(update: dict[str, Any]) -> None:
    """Process a Telegram Update (message /start or contact)."""
    message = update.get("message") or {}
    if not message:
        return

    chat = message.get("chat") or {}
    chat_id = chat.get("id")
    from_user = message.get("from") or {}
    from_id = from_user.get("id")
    if chat_id is None or from_id is None:
        return

    text = (message.get("text") or "").strip()
    contact = message.get("contact")

    if text.startswith("/start"):
        parts = text.split(maxsplit=1)
        session_id = parts[1].strip() if len(parts) > 1 else ""
        _handle_start(chat_id=chat_id, from_user=from_user, session_id=session_id)
        return

    if contact:
        _handle_contact(
            chat_id=chat_id,
            from_id=int(from_id),
            contact=contact,
            from_user=from_user,
        )


def _handle_start(*, chat_id: int, from_user: dict, session_id: str) -> None:
    if not session_id:
        send_message(
            chat_id,
            "Open Felege Metsahft and tap <b>Continue with Telegram</b> to get a fresh link.",
        )
        return

    now = timezone.now()
    try:
        session = TelegramAuthSession.objects.get(pk=session_id)
    except (TelegramAuthSession.DoesNotExist, ValueError):
        send_message(chat_id, "This link is invalid. Go back to the app and try again.")
        return

    if session.consumed_at is not None or session.is_expired(now=now):
        send_message(chat_id, "This link has expired. Go back to the app and try again.")
        return

    session.telegram_chat_id = int(chat_id)
    session.telegram_user_id = int(from_user.get("id"))
    session.telegram_username = (from_user.get("username") or "")[:64]
    session.status = TelegramAuthSession.Status.AWAITING_CONTACT
    session.save(
        update_fields=[
            "telegram_chat_id",
            "telegram_user_id",
            "telegram_username",
            "status",
        ]
    )
    send_contact_request(chat_id)


def _handle_contact(
    *,
    chat_id: int,
    from_id: int,
    contact: dict,
    from_user: dict,
) -> None:
    # CRITICAL: reject pasted/shared contacts that are not the sender's own.
    contact_user_id = contact.get("user_id")
    if contact_user_id is None or int(contact_user_id) != int(from_id):
        send_message(
            chat_id,
            "Please share <b>your own</b> Telegram contact using the button below.",
        )
        send_contact_request(chat_id)
        return

    now = timezone.now()
    session = (
        TelegramAuthSession.objects.filter(
            telegram_chat_id=int(chat_id),
            consumed_at__isnull=True,
            expires_at__gt=now,
            status__in=[
                TelegramAuthSession.Status.AWAITING_CONTACT,
                TelegramAuthSession.Status.PENDING,
                TelegramAuthSession.Status.CODE_SENT,
            ],
        )
        .order_by("-created_at")
        .first()
    )
    if session is None:
        send_message(chat_id, "Session expired. Start over in the app.")
        return

    try:
        shared_phone = normalize_phone(str(contact.get("phone_number") or ""))
    except ValueError:
        send_message(chat_id, "Could not read that phone number. Try again.")
        return

    if shared_phone != session.phone:
        send_message(
            chat_id,
            "<b>Number mismatch.</b>\n\n"
            "The number you shared does not match what you entered in the app.\n"
            "Go back and use the phone number linked to this Telegram account.",
        )
        return

    raw_code = TelegramAuthSession.generate_raw_code()
    session.code_hash = TelegramAuthSession.hash_code(raw_code)
    session.code_expires_at = now + TelegramAuthSession.CODE_TTL
    session.attempts = 0
    session.telegram_user_id = int(from_id)
    session.telegram_chat_id = int(chat_id)
    session.telegram_username = (from_user.get("username") or session.telegram_username or "")[
        :64
    ]
    session.status = TelegramAuthSession.Status.CODE_SENT
    session.save(
        update_fields=[
            "code_hash",
            "code_expires_at",
            "attempts",
            "telegram_user_id",
            "telegram_chat_id",
            "telegram_username",
            "status",
        ]
    )

    remove_keyboard(
        chat_id,
        f"<b>Your Felege Metsahft code</b>\n\n"
        f"<code>{raw_code}</code>\n\n"
        f"Expires in {int(TelegramAuthSession.CODE_TTL.total_seconds() // 60)} minutes. "
        f"Enter it in the app.",
    )
    logger.info("OTP delivered via Telegram for %s", mask_phone(session.phone))


def send_password_reset_code(*, chat_id: int, code: str, display_name: str = "") -> None:
    name = (display_name or "").strip() or "there"
    send_message(
        chat_id,
        f"Hi {name},\n\n"
        f"Your password reset code:\n\n"
        f"<code>{code}</code>\n\n"
        f"Expires in 15 minutes. If you did not request this, ignore this message.",
    )


def notify_telegram_user(*, chat_id: int, title: str, body: str = "") -> None:
    text = f"<b>{_escape_html(title)}</b>"
    if body:
        text += f"\n{_escape_html(body)}"
    send_message(chat_id, text)


def _escape_html(value: str) -> str:
    return (
        (value or "")
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


@transaction.atomic
def attach_telegram_to_user(user, session: TelegramAuthSession) -> None:
    """Bind telegram + verified phone from a verified session onto ``user``."""
    if session.telegram_user_id is None or session.telegram_chat_id is None:
        raise TelegramBotError("Session is missing Telegram identity.")

    conflict_tg = (
        type(user)
        .objects.filter(telegram_user_id=session.telegram_user_id)
        .exclude(pk=user.pk)
        .exists()
    )
    if conflict_tg:
        raise TelegramBotError("This Telegram account is already linked to another user.")

    conflict_phone = (
        type(user)
        .objects.filter(phone=session.phone)
        .exclude(pk=user.pk)
        .exists()
    )
    if conflict_phone:
        raise TelegramBotError("This phone number is already linked to another user.")

    now = timezone.now()
    user.phone = session.phone
    user.phone_verified_at = now
    user.telegram_user_id = session.telegram_user_id
    user.telegram_chat_id = session.telegram_chat_id
    user.telegram_username = session.telegram_username or ""
    user.telegram_linked_at = now
    user.save(
        update_fields=[
            "phone",
            "phone_verified_at",
            "telegram_user_id",
            "telegram_chat_id",
            "telegram_username",
            "telegram_linked_at",
        ]
    )
