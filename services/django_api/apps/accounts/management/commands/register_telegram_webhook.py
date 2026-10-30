"""Register (or clear) the Telegram auth bot webhook.

Usage (API container / host with Django settings)::

    python manage.py register_telegram_webhook
    python manage.py register_telegram_webhook --clear

Requires TELEGRAM_AUTH_BOT_TOKEN and TELEGRAM_AUTH_WEBHOOK_URL (and secret
when TELEGRAM_AUTH_REQUIRE_WEBHOOK_SECRET is true).
"""

from django.core.management.base import BaseCommand, CommandError

from apps.accounts import telegram_bot


class Command(BaseCommand):
    help = "Register the Felege Telegram auth bot webhook with BotFather API."

    def add_arguments(self, parser):
        parser.add_argument(
            "--clear",
            action="store_true",
            help="Delete the webhook instead of registering it.",
        )

    def handle(self, *args, **options):
        if options["clear"]:
            if not telegram_bot.bot_configured():
                raise CommandError("TELEGRAM_AUTH_BOT_TOKEN is not set.")
            telegram_bot.bot_api("deleteWebhook", {"drop_pending_updates": True})
            self.stdout.write(self.style.SUCCESS("Telegram webhook cleared."))
            return

        ok = telegram_bot.register_webhook()
        if not ok:
            raise CommandError(
                "Webhook registration failed. Check TELEGRAM_AUTH_BOT_TOKEN, "
                "TELEGRAM_AUTH_WEBHOOK_URL, and TELEGRAM_AUTH_WEBHOOK_SECRET."
            )
        self.stdout.write(self.style.SUCCESS("Telegram auth webhook registered."))
