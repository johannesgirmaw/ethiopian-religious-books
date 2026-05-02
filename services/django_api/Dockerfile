FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=config.settings.prod

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY . .

# Bake admin / DRF static into the image (no runtime dependency on external storage).
RUN DJANGO_SECRET_KEY=collectstatic-build-only \
    DATABASE_URL=sqlite:////tmp/collectstatic.db \
    python manage.py collectstatic --noinput

# Compose maps host:8000 → container:8000 with PORT unset (${PORT:-8000}). Render sets PORT (often 10000).
EXPOSE 8000
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/sh", "-c", "exec gunicorn config.wsgi:application --bind 0.0.0.0:${PORT:-8000} --workers 2"]
