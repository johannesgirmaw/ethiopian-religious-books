"""Transactional email for account/password flows.

``send_password_reset_email`` does the actual delivery; ``dispatch_password_reset_email``
is the entry point callers use — it hands the work to Celery when a broker is
reachable and otherwise sends inline, so password reset always works in
development (console backend, no worker) and scales in production.
"""
from __future__ import annotations

import logging

from django.conf import settings
from django.core.mail import EmailMultiAlternatives

logger = logging.getLogger(__name__)

_SUBJECT = "Your password reset code"


def _from_email() -> str:
    return getattr(settings, "DEFAULT_FROM_EMAIL", None) or "no-reply@ethiopianreader.app"


def send_password_reset_email(*, email: str, code: str, display_name: str = "") -> None:
    """Render and send the password-reset code email (synchronous)."""
    name = (display_name or "").strip() or "there"
    ttl_minutes = 15

    text_body = (
        f"Hi {name},\n\n"
        f"Use this code to reset your password:\n\n"
        f"    {code}\n\n"
        f"The code expires in {ttl_minutes} minutes and can be used once.\n"
        f"If you didn't request a password reset, you can safely ignore this email — "
        f"your password will not change.\n\n"
        f"— Ethiopian Reader"
    )

    html_body = f"""\
<div style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;max-width:480px;margin:0 auto;color:#2B2F33">
  <h2 style="margin:0 0 8px;font-size:20px;color:#14708F">Password reset</h2>
  <p style="margin:0 0 16px;color:#5A6169">Hi {name}, use the code below to reset your password.</p>
  <div style="font-size:32px;font-weight:700;letter-spacing:8px;background:#F4F8FB;border:1px solid #E2E8EF;border-radius:12px;padding:16px;text-align:center;color:#14708F">{code}</div>
  <p style="margin:16px 0 0;font-size:13px;color:#8A9199">This code expires in {ttl_minutes} minutes and can be used once. If you didn't request a password reset, you can safely ignore this email.</p>
  <p style="margin:16px 0 0;font-size:13px;color:#8A9199">— Ethiopian Reader</p>
</div>"""

    message = EmailMultiAlternatives(
        subject=_SUBJECT,
        body=text_body,
        from_email=_from_email(),
        to=[email],
    )
    message.attach_alternative(html_body, "text/html")
    message.send(fail_silently=False)


def dispatch_password_reset_email(*, email: str, code: str, display_name: str = "") -> None:
    """Deliver the reset email.

    Sends inline by default so delivery is reliable wherever the API runs (no
    Celery worker is required). Set ``PASSWORD_RESET_EMAIL_ASYNC=True`` once a
    worker is consuming the queue to offload sending; if enqueueing fails we fall
    back to an inline send so a reset is never silently dropped.
    """
    if getattr(settings, "PASSWORD_RESET_EMAIL_ASYNC", False):
        try:
            from apps.accounts.tasks import send_password_reset_email_task

            send_password_reset_email_task.delay(email, code, display_name)
            return
        except Exception:  # broker unavailable / enqueue failure
            logger.warning("Password reset email enqueue failed; sending inline.")
    send_password_reset_email(email=email, code=code, display_name=display_name)
