from django.db.models import Count, Max
from django.utils import timezone


def compute_catalog_etag(queryset):
    agg = queryset.aggregate(m=Max("updated_at"), c=Count("id"))
    if agg["m"] is None:
        return 'W/"cat-empty"'
    return f'W/"cat-{agg["m"].isoformat()}-{agg["c"]}"'


def catalog_response_extras():
    return {"server_time": timezone.now().isoformat().replace("+00:00", "Z")}
