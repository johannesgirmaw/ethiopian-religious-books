from rest_framework import serializers

from apps.study.models import (
    BookReview,
    DailyReadingPlan,
    DailyReadingPlanItem,
    ReaderEvent,
    ReminderPreference,
    StudyFolder,
    StudyFolderEntry,
    StudyReminder,
    UserBookmark,
    UserFavourite,
    UserHighlight,
    UserNote,
    UserNotification,
    UserReadingProgress,
)


class UserFavouriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserFavourite
        fields = ("id", "book", "created_at")
        read_only_fields = ("id", "created_at")


class BookReviewSerializer(serializers.ModelSerializer):
    user_name = serializers.SerializerMethodField()

    class Meta:
        model = BookReview
        fields = (
            "id",
            "book",
            "rating",
            "body",
            "user_name",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "user_name", "created_at", "updated_at")

    def get_user_name(self, obj: BookReview) -> str:
        name = (getattr(obj.user, "display_name", "") or "").strip()
        return name or obj.user.email.split("@")[0]

    def validate_rating(self, value: int) -> int:
        if value < 1 or value > 5:
            raise serializers.ValidationError("rating must be between 1 and 5")
        return value


class UserNotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserNotification
        fields = ("id", "kind", "title", "body", "book", "is_read", "created_at")
        read_only_fields = fields


class UserBookmarkSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserBookmark
        fields = "__all__"
        read_only_fields = ("id", "user", "created_at")


class UserHighlightSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserHighlight
        fields = "__all__"
        read_only_fields = ("id", "user", "created_at")


class UserNoteSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserNote
        fields = "__all__"
        read_only_fields = ("id", "user", "created_at", "updated_at")


class StudyFolderSerializer(serializers.ModelSerializer):
    class Meta:
        model = StudyFolder
        fields = "__all__"
        read_only_fields = ("id", "user", "created_at", "updated_at")


class StudyFolderEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = StudyFolderEntry
        fields = "__all__"
        read_only_fields = ("id", "created_at")


class DailyReadingPlanItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyReadingPlanItem
        fields = "__all__"
        read_only_fields = ("id", "plan")


class DailyReadingPlanSerializer(serializers.ModelSerializer):
    items = DailyReadingPlanItemSerializer(many=True, required=False)

    class Meta:
        model = DailyReadingPlan
        fields = ("id", "user", "title", "is_active", "created_at", "updated_at", "items")
        read_only_fields = ("id", "user", "created_at", "updated_at")

    def create(self, validated_data):
        items = validated_data.pop("items", [])
        plan = DailyReadingPlan.objects.create(**validated_data)
        for item in items:
            DailyReadingPlanItem.objects.create(plan=plan, **item)
        return plan

    def update(self, instance, validated_data):
        items = validated_data.pop("items", None)
        for key, value in validated_data.items():
            setattr(instance, key, value)
        instance.save()
        if items is not None:
            instance.items.all().delete()
            for item in items:
                DailyReadingPlanItem.objects.create(plan=instance, **item)
        return instance


class ReminderPreferenceSerializer(serializers.ModelSerializer):
    def validate_hour_utc(self, value):
        if value < 0 or value > 23:
            raise serializers.ValidationError("hour_utc must be between 0 and 23")
        return value

    def validate_minute_utc(self, value):
        if value < 0 or value > 59:
            raise serializers.ValidationError("minute_utc must be between 0 and 59")
        return value

    class Meta:
        model = ReminderPreference
        fields = "__all__"
        read_only_fields = ("id", "user", "updated_at")


class StudyReminderSerializer(serializers.ModelSerializer):
    class Meta:
        model = StudyReminder
        fields = "__all__"
        read_only_fields = ("id", "user", "sent_at", "created_at")


class UserReadingProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserReadingProgress
        fields = "__all__"
        read_only_fields = ("id", "user", "book", "last_read_at")

    def validate_progress_percent(self, value):
        if value < 0 or value > 100:
            raise serializers.ValidationError("progress_percent must be between 0 and 100")
        return value


class ReaderEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReaderEvent
        fields = "__all__"
        read_only_fields = ("id", "user", "created_at")
