"""Telegram Bot API helpers for auth OTP and free notifications.

Uses the free Bot API only (no Gateway). Secrets stay server-side.
"""

from __future__ import annotations

import json
import logging
import urllib.error
import urllib.request
from typing import Any
from urllib.parse import urlparse

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone

from apps.accounts.models import PasswordResetCode, TelegramAuthSession
from apps.accounts.phone import mask_phone, normalize_phone

User = get_user_model()

logger = logging.getLogger(__name__)

_API_TIMEOUT_S = 10

# Hosts allowed for post-confirm return deep links (client-supplied).
_ALLOWED_RETURN_HOSTS = frozenset(
    {
        "localhost",
        "127.0.0.1",
        "[::1]",
        "app.felegemetsahft.com",
        "felegemetsahft.com",
        "www.felegemetsahft.com",
    }
)


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


def sanitize_client_return_url(raw: str | None) -> str:
    """Allow only localhost / production app hosts for return deep links."""
    value = (raw or "").strip()
    if not value:
        return ""
    try:
        parsed = urlparse(value)
    except Exception:
        return ""
    if parsed.scheme not in ("http", "https"):
        return ""
    host = (parsed.hostname or "").lower()
    if host not in _ALLOWED_RETURN_HOSTS and not host.endswith(".felegemetsahft.com"):
        return ""
    # Normalize: drop query/fragment noise; keep path (incl. hash routes as path+fragment).
    # Flutter web uses /#/auth/telegram — fragment is significant.
    path = parsed.path or "/"
    fragment = parsed.fragment or ""
    if fragment:
        return f"{parsed.scheme}://{parsed.netloc}{path}#{fragment}"
    return f"{parsed.scheme}://{parsed.netloc}{path.rstrip('/')}"


def append_session_query(base: str, session_id: str | Any) -> str:
    """Attach ``session=`` to a client or settings return base URL."""
    base = (base or "").strip()
    if not base:
        return ""
    # Hash routes: https://host/#/path → https://host/#/path?session=
    if "#" in base:
        before, after = base.split("#", 1)
        if "?" in after:
            return f"{before}#{after}&session={session_id}"
        return f"{before}#{after}?session={session_id}"
    sep = "&" if "?" in base else "?"
    return f"{base}{sep}session={session_id}"


def public_return_button_url(session_id: str | Any) -> str | None:
    """HTTPS URL Telegram can put on an inline button (localhost is rejected).

    Uses the public API host from the webhook URL so a cloudflared / prod API
    can 302-redirect to the client's local or production app URL.
    """
    webhook = (getattr(settings, "TELEGRAM_AUTH_WEBHOOK_URL", "") or "").strip()
    if webhook.endswith("/webhook"):
        return f"{webhook[: -len('/webhook')]}/return?session={session_id}"
    base = (getattr(settings, "TELEGRAM_AUTH_APP_RETURN_BASE", "") or "").strip()
    if base:
        return append_session_query(base, session_id) or None
    return None


def final_app_url_for_session(session: TelegramAuthSession) -> str | None:
    """Where the browser should land after the Telegram return redirect."""
    if session.client_return_url:
        return append_session_query(session.client_return_url, session.id) or None
    base = (getattr(settings, "TELEGRAM_AUTH_APP_RETURN_BASE", "") or "").strip()
    if base:
        return append_session_query(base, session.id) or None
    return None


def send_contact_request(
    chat_id: int | str,
    *,
    link_mode: bool = False,
    password_reset: bool = False,
) -> None:
    """Ask once for the user's own Telegram phone (Telegram's consent UI).

    Telegram always shows its own share-phone dialog — bots cannot skip it.
    Returning linked users never reach this (see ``_handle_start``).
    """
    if password_reset:
        text = (
            "<b>Password reset</b>\n\n"
            "Tap <b>Confirm my phone</b>, then OK on Telegram’s prompt.\n"
            "We will send your reset code here."
        )
    elif link_mode:
        text = (
            "<b>One-time setup</b>\n\n"
            "Tap <b>Confirm my phone</b>, then OK on Telegram’s prompt.\n"
            "We only need this once to link your account."
        )
    else:
        text = (
            "<b>First-time sign-in</b>\n\n"
            "Tap <b>Confirm my phone</b>, then OK on Telegram’s prompt.\n"
            "Next time you sign in, this step is skipped."
        )
    send_message(
        chat_id,
        text,
        reply_markup={
            "keyboard": [[{"text": "Confirm my phone", "request_contact": True}]],
            "resize_keyboard": True,
            "one_time_keyboard": True,
        },
    )


def send_done_with_return(
    chat_id: int | str,
    *,
    session_id: str | Any,
    linked: bool,
) -> None:
    """Remove the contact keyboard and offer a one-tap return to the app."""
    if linked:
        body = (
            "<b>Telegram linked.</b>\n\n"
            "Return to Felege Metsahft — you are done."
        )
        button = "Open Felege Metsahft"
    else:
        body = (
            "<b>Phone confirmed.</b>\n\n"
            "Return to Felege Metsahft to finish signing in."
        )
        button = "Open Felege Metsahft"

    remove_keyboard(chat_id, body)
    url = public_return_button_url(session_id)
    if url:
        send_message(
            chat_id,
            "Tap below to open the app:",
            reply_markup={
                "inline_keyboard": [[{"text": button, "url": url}]],
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
    raw_phone: str | None = None,
    purpose: str,
    user=None,
    ip: str | None = None,
    return_url: str | None = None,
) -> tuple[TelegramAuthSession, str]:
    """Create a deep-link session; returns (session, bot_link).

    ``phone_link`` may omit the phone — it is taken from Telegram contact share.
    ``login`` still accepts an optional phone; if omitted, contact sets it.
    ``return_url`` is the local or production app URL opened after Confirm.
    """
    if not bot_configured():
        raise TelegramBotError("Telegram auth is not configured.")

    if purpose not in {
        TelegramAuthSession.Purpose.LOGIN,
        TelegramAuthSession.Purpose.PHONE_LINK,
        TelegramAuthSession.Purpose.PASSWORD_RESET,
    }:
        raise ValueError("Invalid purpose.")

    if (
        purpose
        in {
            TelegramAuthSession.Purpose.PHONE_LINK,
            TelegramAuthSession.Purpose.PASSWORD_RESET,
        }
        and user is None
    ):
        raise ValueError(f"{purpose} requires a user.")

    phone = ""
    if raw_phone and str(raw_phone).strip():
        phone = normalize_phone(str(raw_phone))

    safe_return = sanitize_client_return_url(return_url)

    now = timezone.now()
    # Cooldown: per user for link/reset, per phone (or IP) for login.
    cooldown_qs = TelegramAuthSession.objects.filter(
        purpose=purpose,
        created_at__gte=now - TelegramAuthSession.INITIATE_COOLDOWN,
        consumed_at__isnull=True,
    )
    if purpose in {
        TelegramAuthSession.Purpose.PHONE_LINK,
        TelegramAuthSession.Purpose.PASSWORD_RESET,
    }:
        cooldown_qs = cooldown_qs.filter(user=user)
    elif phone:
        cooldown_qs = cooldown_qs.filter(phone=phone)
    else:
        cooldown_qs = cooldown_qs.filter(phone="", requested_ip=ip)

    existing = (
        cooldown_qs.filter(expires_at__gt=now).order_by("-created_at").first()
    )
    if existing is not None:
        if safe_return and existing.client_return_url != safe_return:
            existing.client_return_url = safe_return
            existing.save(update_fields=["client_return_url"])
        username = settings.TELEGRAM_AUTH_BOT_USERNAME.lstrip("@")
        return existing, f"https://t.me/{username}?start={existing.id}"

    # Expire prior open sessions for this scope.
    expire_qs = TelegramAuthSession.objects.filter(
        purpose=purpose, consumed_at__isnull=True
    )
    if purpose in {
        TelegramAuthSession.Purpose.PHONE_LINK,
        TelegramAuthSession.Purpose.PASSWORD_RESET,
    }:
        expire_qs = expire_qs.filter(user=user)
    elif phone:
        expire_qs = expire_qs.filter(phone=phone)
    expire_qs.update(status=TelegramAuthSession.Status.EXPIRED, consumed_at=now)

    bind_user = purpose in {
        TelegramAuthSession.Purpose.PHONE_LINK,
        TelegramAuthSession.Purpose.PASSWORD_RESET,
    }
    session = TelegramAuthSession.objects.create(
        phone=phone,
        purpose=purpose,
        user=user if bind_user else None,
        expires_at=now + TelegramAuthSession.SESSION_TTL,
        requested_ip=ip,
        client_return_url=safe_return,
    )
    username = settings.TELEGRAM_AUTH_BOT_USERNAME.lstrip("@")
    bot_link = f"https://t.me/{username}?start={session.id}"
    logger.info(
        "Telegram auth session %s created for %s (%s)",
        session.id,
        mask_phone(phone) if phone else "(phone from Telegram)",
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
            "Open Felege Metsahft and tap <b>Sign in with Telegram</b> to get a fresh link.",
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

    from_id = int(from_user.get("id"))
    session.telegram_chat_id = int(chat_id)
    session.telegram_user_id = from_id
    session.telegram_username = (from_user.get("username") or "")[:64]

    # Returning linked user: Telegram already proved identity via /start —
    # skip the share-phone modal entirely.
    if session.purpose == TelegramAuthSession.Purpose.LOGIN:
        linked = (
            User.objects.filter(
                telegram_user_id=from_id,
                deleted_at__isnull=True,
                is_active=True,
            )
            .only("id", "phone")
            .first()
        )
        if linked is not None:
            if linked.phone and not session.phone:
                session.phone = linked.phone
            session.status = TelegramAuthSession.Status.VERIFIED
            session.save(
                update_fields=[
                    "phone",
                    "telegram_chat_id",
                    "telegram_user_id",
                    "telegram_username",
                    "status",
                ]
            )
            send_done_with_return(chat_id, session_id=session.id, linked=False)
            logger.info(
                "Telegram login session %s verified without contact (linked user %s)",
                session.id,
                linked.id,
            )
            return

    # Already linked to this account (Settings → Link again).
    if (
        session.purpose == TelegramAuthSession.Purpose.PHONE_LINK
        and session.user_id
        and session.user.telegram_user_id == from_id
    ):
        session.status = TelegramAuthSession.Status.VERIFIED
        session.consumed_at = now
        if session.user.phone and not session.phone:
            session.phone = session.user.phone
        session.save(
            update_fields=[
                "phone",
                "telegram_chat_id",
                "telegram_user_id",
                "telegram_username",
                "status",
                "consumed_at",
            ]
        )
        send_done_with_return(chat_id, session_id=session.id, linked=True)
        return

    # Password reset: if this Telegram is already on the account, send code now.
    if (
        session.purpose == TelegramAuthSession.Purpose.PASSWORD_RESET
        and session.user_id
        and (
            session.user.telegram_user_id == from_id
            or session.user.telegram_chat_id == int(chat_id)
        )
    ):
        session.telegram_chat_id = int(chat_id)
        session.telegram_user_id = from_id
        session.telegram_username = (from_user.get("username") or "")[:64]
        if session.user.phone and not session.phone:
            session.phone = session.user.phone
        session.save(
            update_fields=[
                "phone",
                "telegram_chat_id",
                "telegram_user_id",
                "telegram_username",
            ]
        )
        try:
            deliver_password_reset_code(session=session, user=session.user)
        except TelegramBotError as exc:
            send_message(chat_id, f"Could not send reset code: {exc}")
        return

    session.status = TelegramAuthSession.Status.AWAITING_CONTACT
    session.save(
        update_fields=[
            "telegram_chat_id",
            "telegram_user_id",
            "telegram_username",
            "status",
        ]
    )
    send_contact_request(
        chat_id,
        link_mode=session.purpose == TelegramAuthSession.Purpose.PHONE_LINK,
        password_reset=session.purpose
        == TelegramAuthSession.Purpose.PASSWORD_RESET,
    )


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

    if session.phone and shared_phone != session.phone:
        send_message(
            chat_id,
            "<b>Number mismatch.</b>\n\n"
            "The number you shared does not match what you entered in the app.\n"
            "Go back and use the phone number linked to this Telegram account.",
        )
        return

    session.phone = shared_phone
    session.telegram_user_id = int(from_id)
    session.telegram_chat_id = int(chat_id)
    session.telegram_username = (
        from_user.get("username") or session.telegram_username or ""
    )[:64]

    # Linking while signed-in: contact proof is enough — no OTP round-trip.
    if session.purpose == TelegramAuthSession.Purpose.PHONE_LINK:
        if session.user_id is None:
            send_message(chat_id, "Session expired. Start over in the app.")
            return
        try:
            attach_telegram_to_user(session.user, session)
        except TelegramBotError as exc:
            remove_keyboard(chat_id, f"Could not link: {exc}")
            return
        session.status = TelegramAuthSession.Status.VERIFIED
        session.consumed_at = now
        session.save(
            update_fields=[
                "phone",
                "telegram_user_id",
                "telegram_chat_id",
                "telegram_username",
                "status",
                "consumed_at",
            ]
        )
        send_done_with_return(chat_id, session_id=session.id, linked=True)
        logger.info("Telegram linked for user %s via %s", session.user_id, mask_phone(shared_phone))
        return

    # Password reset: link Telegram if needed, then DM the reset code.
    if session.purpose == TelegramAuthSession.Purpose.PASSWORD_RESET:
        if session.user_id is None:
            send_message(chat_id, "Session expired. Start over in the app.")
            return
        session.save(
            update_fields=[
                "phone",
                "telegram_user_id",
                "telegram_chat_id",
                "telegram_username",
            ]
        )
        try:
            if not session.user.telegram_linked:
                attach_telegram_to_user(session.user, session)
            else:
                # Refresh chat id if the user reinstalled Telegram, etc.
                if session.user.telegram_user_id != session.telegram_user_id:
                    raise TelegramBotError(
                        "This Telegram account does not match the one on file."
                    )
                session.user.telegram_chat_id = session.telegram_chat_id
                session.user.save(update_fields=["telegram_chat_id"])
            deliver_password_reset_code(session=session, user=session.user)
        except TelegramBotError as exc:
            remove_keyboard(chat_id, f"Could not reset password: {exc}")
        return

    # Login / sign-up: contact proof verifies the session; the app claims tokens
    # (or asks for email) — no OTP to type.
    session.attempts = 0
    session.status = TelegramAuthSession.Status.VERIFIED
    session.code_hash = ""
    session.code_expires_at = None
    session.save(
        update_fields=[
            "phone",
            "attempts",
            "telegram_user_id",
            "telegram_chat_id",
            "telegram_username",
            "status",
            "code_hash",
            "code_expires_at",
        ]
    )
    send_done_with_return(chat_id, session_id=session.id, linked=False)
    logger.info(
        "Telegram login session %s verified via contact for %s",
        session.id,
        mask_phone(session.phone),
    )


def send_password_reset_code(*, chat_id: int, code: str, display_name: str = "") -> None:
    name = (display_name or "").strip() or "there"
    send_message(
        chat_id,
        f"Hi {name},\n\n"
        f"Your password reset code:\n\n"
        f"<code>{code}</code>\n\n"
        f"Expires in 15 minutes. If you did not request this, ignore this message.",
    )


def deliver_password_reset_code(*, session: TelegramAuthSession, user) -> None:
    """Issue a PasswordResetCode and DM it; mark the Telegram session CODE_SENT."""
    if session.telegram_chat_id is None:
        raise TelegramBotError("Missing Telegram chat.")

    now = timezone.now()
    PasswordResetCode.objects.filter(user=user, consumed_at__isnull=True).update(
        consumed_at=now
    )
    _, raw_code = PasswordResetCode.issue(
        user,
        ip=session.requested_ip,
        channel=PasswordResetCode.Channel.TELEGRAM,
    )
    send_password_reset_code(
        chat_id=int(session.telegram_chat_id),
        code=raw_code,
        display_name=user.display_name,
    )
    session.status = TelegramAuthSession.Status.CODE_SENT
    session.consumed_at = now
    session.save(update_fields=["status", "consumed_at"])
    remove_keyboard(
        session.telegram_chat_id,
        "<b>Reset code sent.</b>\n\n"
        "Enter it in Felege Metsahft to choose a new password.",
    )
    url = public_return_button_url(session.id)
    if url:
        send_message(
            session.telegram_chat_id,
            "Tap below to open the app:",
            reply_markup={
                "inline_keyboard": [[{"text": "Open Felege Metsahft", "url": url}]],
            },
        )
    logger.info(
        "Password reset code sent via Telegram for user %s",
        user.pk,
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
