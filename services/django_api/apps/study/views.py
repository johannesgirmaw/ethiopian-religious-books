from django.conf import settings
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.models import Book
from apps.study.models import (
    DailyReadingPlan,
    ReaderEvent,
    ReminderPreference,
    StudyFolder,
    StudyFolderEntry,
    StudyReminder,
    UserBookmark,
    UserHighlight,
    UserNote,
    UserReadingProgress,
)
from apps.study.serializers import (
    DailyReadingPlanSerializer,
    ReaderEventSerializer,
    ReminderPreferenceSerializer,
    StudyFolderEntrySerializer,
    StudyFolderSerializer,
    StudyReminderSerializer,
    UserBookmarkSerializer,
    UserHighlightSerializer,
    UserNoteSerializer,
    UserReadingProgressSerializer,
)


class _OwnedModelView(APIView):
    permission_classes = [IsAuthenticated]
    model = None
    serializer_class = None

    def _feature_disabled_response(self):
        if not settings.FEATURE_STUDY_TOOLS:
            return Response(
                {"error": {"code": "FEATURE_DISABLED", "message": "Study tools are disabled."}},
                status=status.HTTP_404_NOT_FOUND,
            )
        return None

    def get_queryset(self, request):
        return self.model.objects.filter(user=request.user)

    def get(self, request):
        disabled = self._feature_disabled_response()
        if disabled is not None:
            return disabled
        items = self.get_queryset(request)
        return Response({"items": self.serializer_class(items, many=True).data})

    def post(self, request):
        disabled = self._feature_disabled_response()
        if disabled is not None:
            return disabled
        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        obj = serializer.save(user=request.user)
        return Response(self.serializer_class(obj).data, status=status.HTTP_201_CREATED)


class _OwnedModelDetailView(APIView):
    permission_classes = [IsAuthenticated]
    model = None
    serializer_class = None

    def _feature_disabled_response(self):
        if not settings.FEATURE_STUDY_TOOLS:
            return Response(
                {"error": {"code": "FEATURE_DISABLED", "message": "Study tools are disabled."}},
                status=status.HTTP_404_NOT_FOUND,
            )
        return None

    def patch(self, request, item_id):
        disabled = self._feature_disabled_response()
        if disabled is not None:
            return disabled
        obj = get_object_or_404(self.model, pk=item_id, user=request.user)
        serializer = self.serializer_class(obj, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(self.serializer_class(obj).data)

    def delete(self, request, item_id):
        disabled = self._feature_disabled_response()
        if disabled is not None:
            return disabled
        obj = get_object_or_404(self.model, pk=item_id, user=request.user)
        obj.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class StudyBookmarksView(_OwnedModelView):
    model = UserBookmark
    serializer_class = UserBookmarkSerializer


class StudyBookmarkDetailView(_OwnedModelDetailView):
    model = UserBookmark
    serializer_class = UserBookmarkSerializer


class StudyHighlightsView(_OwnedModelView):
    model = UserHighlight
    serializer_class = UserHighlightSerializer


class StudyHighlightDetailView(_OwnedModelDetailView):
    model = UserHighlight
    serializer_class = UserHighlightSerializer


class StudyNotesView(_OwnedModelView):
    model = UserNote
    serializer_class = UserNoteSerializer


class StudyNoteDetailView(_OwnedModelDetailView):
    model = UserNote
    serializer_class = UserNoteSerializer


class StudyFoldersView(_OwnedModelView):
    model = StudyFolder
    serializer_class = StudyFolderSerializer


class StudyFolderDetailView(_OwnedModelDetailView):
    model = StudyFolder
    serializer_class = StudyFolderSerializer


class StudyFolderEntriesView(APIView):
    permission_classes = [IsAuthenticated]

    def _feature_disabled_response(self):
        if not settings.FEATURE_STUDY_TOOLS:
            return Response(
                {"error": {"code": "FEATURE_DISABLED", "message": "Study tools are disabled."}},
                status=status.HTTP_404_NOT_FOUND,
            )
        return None

    def get(self, request):
        disabled = self._feature_disabled_response()
        if disabled is not None:
            return disabled
        folder_id = request.query_params.get("folder_id")
        qs = StudyFolderEntry.objects.filter(folder__user=request.user)
        if folder_id:
            qs = qs.filter(folder_id=folder_id)
        return Response({"items": StudyFolderEntrySerializer(qs, many=True).data})

    def post(self, request):
        disabled = self._feature_disabled_response()
        if disabled is not None:
            return disabled
        serializer = StudyFolderEntrySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        folder = get_object_or_404(StudyFolder, pk=serializer.validated_data["folder"].id, user=request.user)
        obj = serializer.save(folder=folder)
        return Response(StudyFolderEntrySerializer(obj).data, status=status.HTTP_201_CREATED)


class StudyFolderEntryDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, item_id):
        if not settings.FEATURE_STUDY_TOOLS:
            return Response(
                {"error": {"code": "FEATURE_DISABLED", "message": "Study tools are disabled."}},
                status=status.HTTP_404_NOT_FOUND,
            )
        obj = get_object_or_404(StudyFolderEntry, pk=item_id, folder__user=request.user)
        obj.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class DailyReadingPlansView(_OwnedModelView):
    model = DailyReadingPlan
    serializer_class = DailyReadingPlanSerializer


class DailyReadingPlanDetailView(_OwnedModelDetailView):
    model = DailyReadingPlan
    serializer_class = DailyReadingPlanSerializer


class ReminderPreferenceView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not settings.FEATURE_DAILY_PLAN_REMINDERS:
            return Response(
                {"error": {"code": "FEATURE_DISABLED", "message": "Daily reminders are disabled."}},
                status=status.HTTP_404_NOT_FOUND,
            )
        pref, _ = ReminderPreference.objects.get_or_create(user=request.user)
        return Response(ReminderPreferenceSerializer(pref).data)

    def put(self, request):
        if not settings.FEATURE_DAILY_PLAN_REMINDERS:
            return Response(
                {"error": {"code": "FEATURE_DISABLED", "message": "Daily reminders are disabled."}},
                status=status.HTTP_404_NOT_FOUND,
            )
        pref, _ = ReminderPreference.objects.get_or_create(user=request.user)
        serializer = ReminderPreferenceSerializer(pref, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(ReminderPreferenceSerializer(pref).data)


class StudyRemindersView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not settings.FEATURE_DAILY_PLAN_REMINDERS:
            return Response(
                {"error": {"code": "FEATURE_DISABLED", "message": "Daily reminders are disabled."}},
                status=status.HTTP_404_NOT_FOUND,
            )
        qs = StudyReminder.objects.filter(user=request.user).order_by("-scheduled_for")[:100]
        return Response({"items": StudyReminderSerializer(qs, many=True).data})


class StudyReadingProgressView(APIView):
    permission_classes = [IsAuthenticated]

    def _feature_disabled_response(self):
        if not settings.FEATURE_STUDY_TOOLS:
            return Response(
                {"error": {"code": "FEATURE_DISABLED", "message": "Study tools are disabled."}},
                status=status.HTTP_404_NOT_FOUND,
            )
        return None

    def get(self, request, book_id):
        disabled = self._feature_disabled_response()
        if disabled is not None:
            return disabled
        book = get_object_or_404(Book, pk=book_id)
        row = UserReadingProgress.objects.filter(user=request.user, book=book).first()
        if row is None:
            return Response(
                {
                    "book": str(book.id),
                    "chapter_key": "",
                    "page_number": None,
                    "progress_percent": 0,
                    "revision": None,
                }
            )
        return Response(UserReadingProgressSerializer(row).data)

    def put(self, request, book_id):
        disabled = self._feature_disabled_response()
        if disabled is not None:
            return disabled
        book = get_object_or_404(Book, pk=book_id)
        row, _ = UserReadingProgress.objects.get_or_create(user=request.user, book=book)
        serializer = UserReadingProgressSerializer(row, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save(user=request.user, book=book)
        return Response(UserReadingProgressSerializer(row).data)


class ReaderEventsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not settings.FEATURE_STUDY_TOOLS:
            return Response(
                {"error": {"code": "FEATURE_DISABLED", "message": "Study tools are disabled."}},
                status=status.HTTP_404_NOT_FOUND,
            )
        serializer = ReaderEventSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        event = serializer.save(user=request.user)
        return Response(ReaderEventSerializer(event).data, status=status.HTTP_201_CREATED)
