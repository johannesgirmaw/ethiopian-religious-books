from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path
from django.views.decorators.http import require_GET
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView
from rest_framework.permissions import AllowAny

from apps.api_urls import urlpatterns as v1_urlpatterns


def healthz(_request):
    return JsonResponse({"status": "ok"})


@require_GET
def root(_request):
    """Avoid noisy 404s on `/` for bare API hosts (e.g. Render health checks or curiosity hits)."""
    return JsonResponse(
        {
            "service": "Ethiopian Religious Books API",
            "health": "/healthz/",
            "admin": "/admin/",
            "openapi_schema": "/api/schema/",
            "api_docs": "/api/docs/",
            "api_v1": "/v1/",
        }
    )


urlpatterns = [
    path("", root),
    path("admin/", admin.site.urls),
    path("healthz/", healthz),
    path("api/schema/", SpectacularAPIView.as_view(permission_classes=[AllowAny]), name="schema"),
    path(
        "api/docs/",
        SpectacularSwaggerView.as_view(url_name="schema", permission_classes=[AllowAny]),
        name="swagger-ui",
    ),
    path("v1/", include(v1_urlpatterns)),
]
