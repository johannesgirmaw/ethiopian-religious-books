import os

from django.core.management.base import BaseCommand

from apps.accounts.models import User


class Command(BaseCommand):
    help = (
        "Create a superuser from BOOTSTRAP_SUPERUSER_EMAIL and BOOTSTRAP_SUPERUSER_PASSWORD "
        "if that user does not exist (idempotent)."
    )

    def handle(self, *args, **options):
        email = (os.environ.get("BOOTSTRAP_SUPERUSER_EMAIL") or "").strip()
        password = os.environ.get("BOOTSTRAP_SUPERUSER_PASSWORD") or ""
        if not email or not password:
            missing = [
                name
                for name, ok in (
                    ("BOOTSTRAP_SUPERUSER_EMAIL", bool(email)),
                    ("BOOTSTRAP_SUPERUSER_PASSWORD", bool(password)),
                )
                if not ok
            ]
            self.stdout.write(
                self.style.WARNING(
                    "ensure_superuser: no admin user created (missing: "
                    f"{', '.join(missing)}). Set these on the web service in Render → Environment, "
                    "then redeploy. If you use a Blueprint, sync from `render.yaml` or add the vars there."
                )
            )
            return
        if User.objects.filter(email__iexact=email).exists():
            self.stdout.write(f"ensure_superuser: already exists ({email})")
            return
        User.objects.create_superuser(email=email, password=password, role="admin")
        self.stdout.write(self.style.SUCCESS(f"ensure_superuser: created {email}"))
