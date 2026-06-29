import uuid

from django.conf import settings
from django.db import models


class Genre(models.Model):
    """Dynamic book category. Managed via Django admin / the genres API so new
    categories can be added without a code change."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    slug = models.SlugField(max_length=64, unique=True)
    label = models.CharField(max_length=120)
    label_am = models.CharField(max_length=120, blank=True)
    icon = models.CharField(max_length=64, blank=True)  # optional material icon
    ordinal = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "genres"
        ordering = ["ordinal", "label"]

    def __str__(self):
        return self.label


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
    # Stores a Genre.slug. Kept as a slug (not FK) so it stays nullable/blank and
    # offline payloads remain simple; validated against the Genre table on write.
    genre = models.CharField(max_length=64, default="other", blank=True)
    published_year = models.PositiveIntegerField(null=True, blank=True)
    rating_average = models.FloatField(default=0)
    rating_count = models.PositiveIntegerField(default=0)
    readers_count = models.PositiveIntegerField(default=0)
    is_premium = models.BooleanField(default=False)
    is_featured = models.BooleanField(default=False)  # "Popular" home banner

    # --- Monetisation (payments app) -------------------------------------
    # The author is a User with the "author" role. Kept nullable so existing
    # catalogue rows (which only carry the free-text ``author_compiler``) keep
    # working; the FK is what drives commission resolution and the revenue
    # ledger.
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="authored_books",
    )
    currency = models.CharField(max_length=3, default="USD")
    price = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    sale_price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Optional discounted price; when set this is what buyers pay.",
    )
    commission_percent = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Optional per-book override of the platform/author commission.",
    )

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


class OfflineDownload(models.Model):
    """Server-side ledger of offline downloads (one row per user + book + device).

    The encrypted book itself lives on the device, not the server — this records
    *that* a download/license was issued so admins can see who has saved what
    offline, on which device, and whether the lease is still active. Upserted on
    every license issue/renew (``renew_count`` counts re-issues).
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="offline_downloads",
    )
    book = models.ForeignKey(
        Book, on_delete=models.CASCADE, related_name="offline_downloads"
    )
    device_id = models.CharField(max_length=128)
    platform = models.CharField(max_length=40, blank=True)
    revision_id = models.CharField(max_length=64, blank=True)
    first_downloaded_at = models.DateTimeField(auto_now_add=True)
    last_licensed_at = models.DateTimeField(auto_now=True)
    license_expires_at = models.DateTimeField(null=True, blank=True)
    renew_count = models.PositiveIntegerField(default=0)

    class Meta:
        db_table = "offline_downloads"
        ordering = ["-last_licensed_at"]
        verbose_name = "Offline book download"
        verbose_name_plural = "Offline book downloads"
        constraints = [
            models.UniqueConstraint(
                fields=["user", "book", "device_id"], name="uniq_offline_download"
            ),
        ]
        indexes = [
            models.Index(fields=["user", "-last_licensed_at"], name="idx_offdl_user"),
            models.Index(fields=["book", "-last_licensed_at"], name="idx_offdl_book"),
        ]

    def __str__(self):
        return f"{self.user_id} · {self.book_id} · {self.device_id[:8]}"
