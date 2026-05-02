import os

from config.settings.base import *  # noqa: F403

DEBUG = False

_mw = list(MIDDLEWARE)
_wn = "whitenoise.middleware.WhiteNoiseMiddleware"
if _wn not in _mw:
    try:
        _i = _mw.index("django.middleware.security.SecurityMiddleware") + 1
    except ValueError:
        _i = 0
    _mw.insert(_i, _wn)
MIDDLEWARE = _mw

STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedStaticFilesStorage",
    },
}

ALLOWED_HOSTS = list(ALLOWED_HOSTS)
_render_host = os.environ.get("RENDER_EXTERNAL_HOSTNAME")
if _render_host and _render_host not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append(_render_host)

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
USE_X_FORWARDED_HOST = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
