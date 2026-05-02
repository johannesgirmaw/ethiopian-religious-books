"""Small WSGI middleware helpers (kept minimal on purpose)."""


class CollapseDuplicatePathSlashesMiddleware:
    """
    Normalize paths like ``//admin`` to ``/admin``. Some proxies or mis-set
    ``SITE_URL`` values produce double slashes and would otherwise 404.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        path_info = request.META.get("PATH_INFO", "")
        if "//" in path_info:
            collapsed = path_info
            while "//" in collapsed:
                collapsed = collapsed.replace("//", "/")
            request.META["PATH_INFO"] = collapsed
        return self.get_response(request)
