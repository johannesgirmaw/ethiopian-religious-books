import datetime

import environ
from pathlib import Path

from django.templatetags.static import static
from django.urls import reverse_lazy
from django.utils.translation import gettext_lazy as _

BASE_DIR = Path(__file__).resolve().parent.parent.parent

env = environ.Env(
    DEBUG=(bool, False),
)

SECRET_KEY = env("DJANGO_SECRET_KEY", default="dev-only-change-in-production")
DEBUG = env.bool("DEBUG", default=False)
ALLOWED_HOSTS = env.list("ALLOWED_HOSTS", default=["localhost", "127.0.0.1", "api"])

INSTALLED_APPS = [
    "unfold",
    "unfold.contrib.filters",
    "unfold.contrib.forms",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",
    "corsheaders",
    "drf_spectacular",
    "apps.accounts",
    "apps.legal",
    "apps.catalog",
    "apps.study",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"

DATABASES = {
    "default": env.db(
        "DATABASE_URL",
        default=f"sqlite:///{BASE_DIR / 'db.sqlite3'}",
    )
}

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_DIRS = [BASE_DIR / "static"]

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
AUTH_USER_MODEL = "accounts.User"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.AllowAny",),
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": datetime.timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": datetime.timedelta(days=14),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Ethiopian Religious Books API",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
}

CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = env.list(
    "CORS_ALLOWED_ORIGINS",
    default=["http://localhost:5173", "http://127.0.0.1:5173"],
)

CELERY_BROKER_URL = env("CELERY_BROKER_URL", default="redis://localhost:6379/0")
CELERY_RESULT_BACKEND = env("CELERY_RESULT_BACKEND", default="redis://localhost:6379/0")

EMAIL_BACKEND = env(
    "EMAIL_BACKEND",
    default="django.core.mail.backends.console.EmailBackend",
)
EMAIL_HOST = env("EMAIL_HOST", default="localhost")
EMAIL_PORT = env.int("EMAIL_PORT", default=1025)
EMAIL_USE_TLS = env.bool("EMAIL_USE_TLS", default=False)

AWS_ACCESS_KEY_ID = env("AWS_ACCESS_KEY_ID", default="")
AWS_SECRET_ACCESS_KEY = env("AWS_SECRET_ACCESS_KEY", default="")
AWS_STORAGE_BUCKET_NAME = env("AWS_STORAGE_BUCKET_NAME", default="religious-books-dev")
AWS_S3_ENDPOINT_URL = env("AWS_S3_ENDPOINT_URL", default="")
# Presigned URLs must use a host reachable by mobile apps (e.g. http://localhost:19000 with default compose host MinIO port, or LAN IP).
AWS_S3_PRESIGN_ENDPOINT_URL = env("AWS_S3_PRESIGN_ENDPOINT_URL", default="")
AWS_S3_REGION_NAME = env("AWS_S3_REGION_NAME", default="us-east-1")
AWS_DEFAULT_ACL = None
AWS_QUERYSTRING_AUTH = True
AWS_S3_ADDRESSING_STYLE = env("AWS_S3_ADDRESSING_STYLE", default="path")

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.Argon2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
]

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "console": {"class": "logging.StreamHandler"},
    },
    "root": {
        "handlers": ["console"],
        "level": "INFO",
    },
}

FEATURE_BOOK_CONTENT_INDEX = env.bool("FEATURE_BOOK_CONTENT_INDEX", default=True)
FEATURE_CATALOG_TOLERANT_SEARCH = env.bool("FEATURE_CATALOG_TOLERANT_SEARCH", default=True)
FEATURE_STUDY_TOOLS = env.bool("FEATURE_STUDY_TOOLS", default=True)
FEATURE_DAILY_PLAN_REMINDERS = env.bool("FEATURE_DAILY_PLAN_REMINDERS", default=True)


def _admin_environment(request):
    if DEBUG:
        return ["Debug", "warning"]
    return ["Production", "success"]


UNFOLD = {
    "SITE_TITLE": _("Ethiopian Religious Books"),
    "SITE_HEADER": _("Religious Books"),
    "SITE_SUBHEADER": _("Catalog, readers, and study tools"),
    "SITE_SYMBOL": "menu_book",
    "SITE_FAVICONS": [
        {
            "rel": "icon",
            "sizes": "32x32",
            "type": "image/svg+xml",
            "href": lambda _request: static("admin/img/icon-book.svg"),
        },
    ],
    "SHOW_LANGUAGES": False,
    "ENVIRONMENT": "config.settings.base._admin_environment",
    "DASHBOARD_CALLBACK": "config.dashboard.dashboard_callback",
    "LOGIN": {
        "image": lambda _request: static("admin/img/login-bg.svg"),
    },
    "COLORS": {
        "primary": {
            "50": "oklch(97% .02 175)",
            "100": "oklch(92% .05 175)",
            "200": "oklch(85% .08 175)",
            "300": "oklch(78% .11 175)",
            "400": "oklch(68% .14 175)",
            "500": "oklch(55% .14 175)",
            "600": "oklch(48% .13 175)",
            "700": "oklch(40% .11 175)",
            "800": "oklch(32% .09 175)",
            "900": "oklch(26% .07 175)",
            "950": "oklch(18% .05 175)",
        },
    },
    "SIDEBAR": {
        "show_search": True,
        "show_all_applications": True,
        "navigation": [
            {
                "title": _("Overview"),
                "separator": True,
                "items": [
                    {
                        "title": _("Dashboard"),
                        "icon": "dashboard",
                        "link": reverse_lazy("admin:index"),
                    },
                    {
                        "title": _("OpenAPI docs"),
                        "icon": "description",
                        "link": reverse_lazy("swagger-ui"),
                    },
                ],
            },
            {
                "title": _("People & access"),
                "collapsible": True,
                "items": [
                    {
                        "title": _("Users"),
                        "icon": "person",
                        "link": reverse_lazy("admin:accounts_user_changelist"),
                    },
                    {
                        "title": _("Groups"),
                        "icon": "group",
                        "link": reverse_lazy("admin:auth_group_changelist"),
                    },
                ],
            },
            {
                "title": _("Catalog & content"),
                "collapsible": True,
                "items": [
                    {
                        "title": _("Books"),
                        "icon": "menu_book",
                        "link": reverse_lazy("admin:catalog_book_changelist"),
                    },
                    {
                        "title": _("Book revisions"),
                        "icon": "history",
                        "link": reverse_lazy("admin:catalog_bookrevision_changelist"),
                    },
                    {
                        "title": _("Tags"),
                        "icon": "label",
                        "link": reverse_lazy("admin:catalog_tag_changelist"),
                    },
                ],
            },
            {
                "title": _("Reader activity (study)"),
                "collapsible": True,
                "items": [
                    {
                        "title": _("Reader events"),
                        "icon": "analytics",
                        "link": reverse_lazy("admin:study_readerevent_changelist"),
                    },
                    {
                        "title": _("Reading progress"),
                        "icon": "percent",
                        "link": reverse_lazy("admin:study_userreadingprogress_changelist"),
                    },
                    {
                        "title": _("Bookmarks"),
                        "icon": "bookmark",
                        "link": reverse_lazy("admin:study_userbookmark_changelist"),
                    },
                    {
                        "title": _("Highlights"),
                        "icon": "format_paint",
                        "link": reverse_lazy("admin:study_userhighlight_changelist"),
                    },
                    {
                        "title": _("Notes"),
                        "icon": "note",
                        "link": reverse_lazy("admin:study_usernote_changelist"),
                    },
                    {
                        "title": _("Daily plans"),
                        "icon": "calendar_month",
                        "link": reverse_lazy("admin:study_dailyreadingplan_changelist"),
                    },
                ],
            },
            {
                "title": _("Compliance"),
                "collapsible": True,
                "items": [
                    {
                        "title": _("Legal documents"),
                        "icon": "gavel",
                        "link": reverse_lazy("admin:legal_legaldocument_changelist"),
                    },
                    {
                        "title": _("Legal acceptances"),
                        "icon": "verified_user",
                        "link": reverse_lazy("admin:legal_legalacceptance_changelist"),
                    },
                ],
            },
        ],
    },
}
