import uuid

from django.conf import settings
from django.db import models


class Book(models.Model):
    class Visibility(models.TextChoices):
        PUBLISHED = "published", "published"
        HIDDEN = "hidden", "hidden"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=500)
    subtitle = models.CharField(max_length=500, blank=True)
    summary = models.TextField(blank=True)
    author_compiler = models.CharField(max_length=500, blank=True)
    primary_language = models.CharField(max_length=32, default="am")
    script_tags = models.JSONField(default=list, blank=True)
    chapters_draft = models.JSONField(default=list, blank=True)
    cover_object_key = models.CharField(max_length=500, blank=True)
    search_text_normalized = models.TextField(blank=True, default="", db_index=True)
    published_revision = models.ForeignKey(
        "BookRevision",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    catalog_visibility = models.CharField(
        max_length=20,
        choices=Visibility.choices,
        default=Visibility.HIDDEN,
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="books_created",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "books"
        ordering = ["title"]

    def save(self, *args, **kwargs):
        from apps.catalog.search_normalization import normalize_search_text

        self.search_text_normalized = normalize_search_text(
            " ".join(
                [
                    self.title or "",
                    self.subtitle or "",
                    self.summary or "",
                    self.author_compiler or "",
                ]
            )
        )
        super().save(*args, **kwargs)


class BookRevision(models.Model):
    class Status(models.TextChoices):
        DRAFT = "draft", "draft"
        PUBLISHED = "published", "published"
        SUPERSEDED = "superseded", "superseded"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name="revisions")
    revision_number = models.PositiveIntegerField()
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    manifest_object_key = models.CharField(max_length=500, blank=True)
    content_object_key = models.CharField(
        max_length=500,
        blank=True,
        help_text="Primary encrypted (or dev plaintext) package blob in object storage.",
    )
    content_format = models.CharField(max_length=64, default="html_chunks")
    total_bytes = models.BigIntegerField(default=0)
    manifest_sha256 = models.CharField(max_length=64, blank=True)
    content_sha256 = models.CharField(max_length=64, blank=True)
    cek_wrapped = models.TextField(blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="revisions_created",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "book_revisions"
        constraints = [
            models.UniqueConstraint(fields=["book", "revision_number"], name="uniq_book_revision_number"),
        ]
        ordering = ["book", "-revision_number"]


class Tag(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    slug = models.SlugField(unique=True, max_length=64)
    label = models.CharField(max_length=200)

    class Meta:
        db_table = "tags"


class BookTag(models.Model):
    book = models.ForeignKey(Book, on_delete=models.CASCADE)
    tag = models.ForeignKey(Tag, on_delete=models.CASCADE)

    class Meta:
        db_table = "book_tags"
        constraints = [
            models.UniqueConstraint(fields=["book", "tag"], name="uniq_book_tag"),
        ]


class BookChapter(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    revision = models.ForeignKey(BookRevision, on_delete=models.CASCADE, related_name="chapters")
    chapter_key = models.CharField(max_length=200)
    title = models.CharField(max_length=500, blank=True)
    ordinal = models.PositiveIntegerField(default=0)
    start_chunk = models.CharField(max_length=200, blank=True)
    end_chunk = models.CharField(max_length=200, blank=True)

    class Meta:
        db_table = "book_chapters"
        ordering = ["revision", "ordinal", "chapter_key"]
        constraints = [
            models.UniqueConstraint(
                fields=["revision", "chapter_key"],
                name="uniq_revision_chapter_key",
            ),
        ]


class BookPage(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    revision = models.ForeignKey(BookRevision, on_delete=models.CASCADE, related_name="pages")
    chapter = models.ForeignKey(
        BookChapter,
        on_delete=models.CASCADE,
        related_name="pages",
        null=True,
        blank=True,
    )
    page_number = models.PositiveIntegerField()
    page_title = models.CharField(max_length=300, blank=True)
    chunk_key = models.CharField(max_length=200, blank=True)
    text_plain = models.TextField(blank=True, default="")

    class Meta:
        db_table = "book_pages"
        ordering = ["revision", "page_number"]
        constraints = [
            models.UniqueConstraint(
                fields=["revision", "page_number"],
                name="uniq_revision_page_number",
            ),
        ]


class BookContentIndex(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name="content_index_rows")
    revision = models.ForeignKey(
        BookRevision,
        on_delete=models.CASCADE,
        related_name="content_index_rows",
    )
    chunk_key = models.CharField(max_length=200, blank=True)
    chapter_key = models.CharField(max_length=200, blank=True)
    page_number = models.PositiveIntegerField(default=1)
    text_plain = models.TextField(blank=True, default="")
    text_normalized = models.TextField(blank=True, default="", db_index=True)

    class Meta:
        db_table = "book_content_index"
        ordering = ["revision", "page_number", "chunk_key"]
        indexes = [
            models.Index(fields=["book", "revision"], name="idx_bci_book_revision"),
            models.Index(fields=["revision", "chapter_key"], name="idx_bci_rev_chapter"),
            models.Index(fields=["revision", "page_number"], name="idx_bci_rev_page"),
        ]
