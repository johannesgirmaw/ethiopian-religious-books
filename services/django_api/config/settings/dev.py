from config.settings.base import *  # noqa: F403

DEBUG = True
ALLOWED_HOSTS = ["*"]

# Flutter web (`flutter run -d chrome`) uses a random localhost port each session.
# Vite admin stays on 5173 via CORS_ALLOWED_ORIGINS in base settings.
CORS_ALLOWED_ORIGIN_REGEXES = [
    r"^http://localhost:\d+$",
    r"^http://127\.0\.0\.1:\d+$",
]
