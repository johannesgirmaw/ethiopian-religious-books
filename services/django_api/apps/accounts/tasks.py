import logging

from celery import shared_task
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone

from apps.study.models import DailyReadingPlan, ReminderPreference, StudyReminder

logger = logging.getLogger(__name__)


@shared_task
def celery_ping() -> str:
    return "pong"


@shared_task
def send_password_reset_email_task(email: str, code: str, display_name: str = "") -> None:
    from apps.accounts.emails import send_password_reset_email

    send_password_reset_email(email=email, code=code, display_name=display_name)


@shared_task(bind=True, max_retries=3, default_retry_delay=30)
def send_telegram_notification_task(
    self, chat_id: int, title: str, body: str = "", user_id: str | None = None
) -> bool:
    """Deliver a free Bot API DM. Rate-limited per user/chat."""
    from apps.accounts.telegram_bot import TelegramBotError, notify_telegram_user

    limit = getattr(settings, "TELEGRAM_NOTIFY_RATE_LIMIT_PER_HOUR", 30)
    bucket_key = f"tg_notify:{user_id or chat_id}:{timezone.now():%Y%m%d%H}"
    try:
        count = cache.get(bucket_key, 0)
        if count >= limit:
            logger.info("Telegram notify rate-limited for %s", bucket_key)
            return False
        cache.set(bucket_key, count + 1, timeout=3600)
        notify_telegram_user(chat_id=chat_id, title=title, body=body)
        return True
    except TelegramBotError as exc:
        logger.warning("Telegram notify failed: %s", exc)
        try:
            raise self.retry(exc=exc)
        except self.MaxRetriesExceededError:
            return False


def dispatch_telegram_notification(*, user, title: str, body: str = "") -> None:
    """Enqueue a Telegram DM when the user has linked Telegram (best-effort)."""
    chat_id = getattr(user, "telegram_chat_id", None)
    if not chat_id:
        return
    from apps.accounts.telegram_bot import bot_configured

    if not bot_configured():
        return
    try:
        send_telegram_notification_task.delay(
            int(chat_id),
            title,
            body or "",
            str(getattr(user, "pk", "") or ""),
        )
    except Exception:
        # Broker down — try inline so notifications still reach Telegram in dev.
        logger.warning("Telegram notify enqueue failed; sending inline.", exc_info=True)
        try:
            from apps.accounts.telegram_bot import notify_telegram_user

            notify_telegram_user(chat_id=int(chat_id), title=title, body=body or "")
        except Exception:
            logger.warning("Inline Telegram notify failed", exc_info=True)


@shared_task
def generate_due_daily_plan_reminders() -> int:
    if not settings.FEATURE_DAILY_PLAN_REMINDERS:
        return 0
    now = timezone.now()
    created = 0
    for pref in ReminderPreference.objects.filter(enabled=True):
        if pref.weekdays_only and now.weekday() >= 5:
            continue
        if now.hour != pref.hour_utc or now.minute != pref.minute_utc:
            continue
        plan = (
            DailyReadingPlan.objects.filter(user=pref.user, is_active=True)
            .prefetch_related("items")
            .first()
        )
        if not plan:
            continue
        day_index = max(1, now.toordinal() % 365)
        plan_item = plan.items.order_by("day_index").filter(day_index__gte=day_index).first()
        if plan_item is None:
            plan_item = plan.items.order_by("day_index").first()
        if plan_item is None:
            continue
        reminder, was_created = StudyReminder.objects.get_or_create(
            user=pref.user,
            plan=plan,
            plan_item=plan_item,
            scheduled_for=now.replace(second=0, microsecond=0),
            defaults={
                "message": (
                    f"Today's reading: {plan_item.book.title}"
                    f" {plan_item.chapter_key or ''}".strip()
                )
            },
        )
        if was_created:
            created += 1
        elif reminder.status == StudyReminder.Status.SKIPPED:
            reminder.status = StudyReminder.Status.PENDING
            reminder.save(update_fields=["status"])
    return created


@shared_task
def dispatch_pending_study_reminders() -> int:
    if not settings.FEATURE_DAILY_PLAN_REMINDERS:
        return 0
    now = timezone.now()
    pending = StudyReminder.objects.filter(
        status=StudyReminder.Status.PENDING,
        scheduled_for__lte=now,
    )[:200]
    count = 0
    for reminder in pending:
        # Placeholder delivery path until push/email adapters are added.
        reminder.status = StudyReminder.Status.SENT
        reminder.sent_at = now
        reminder.save(update_fields=["status", "sent_at"])
        count += 1
    return count
