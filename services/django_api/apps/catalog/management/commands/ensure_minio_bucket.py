from django.core.management.base import BaseCommand

from apps.catalog.storage_s3 import ensure_bucket


class Command(BaseCommand):
    help = "Create S3/MinIO bucket if missing (no-op if AWS_* not configured)."

    def handle(self, *args, **options):
        try:
            ensure_bucket()
        except Exception as exc:
            self.stderr.write(self.style.WARNING(f"ensure_minio_bucket: {exc}"))
            return
        self.stdout.write(self.style.SUCCESS("ensure_minio_bucket: ok"))
