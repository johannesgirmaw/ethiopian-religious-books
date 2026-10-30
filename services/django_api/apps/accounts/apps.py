import logging
import os

from django.apps import AppConfig

logger = logging.getLogger(__name__)


class AccountsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.accounts"
    label = "accounts"

    def ready(self):
        # Register Telegram webhook once per process when explicitly enabled
        # (avoids hammering BotFather on every manage.py command / test run).
        if os.environ.get("TELEGRAM_AUTH_REGISTER_WEBHOOK_ON_START") != "1":
            return
        # Skip during migrate / autodetector / many management commands.
        import sys

        if any(cmd in sys.argv for cmd in ("migrate", "makemigrations", "test", "shell")):
            return
        try:
            from apps.accounts.telegram_bot import register_webhook

            register_webhook()
        except Exception:
            logger.exception("Telegram webhook registration on startup failed")
