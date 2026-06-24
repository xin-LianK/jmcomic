FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    JM_VISUAL_DOWNLOAD_DIR=/data/downloads \
    JM_VISUAL_CACHE_DIR=/data/cache \
    JM_VISUAL_WEB_DIR=/app/web

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY backend/jm_server /app/jm_server
COPY mobile_app/build/web /app/web

VOLUME ["/data/downloads", "/data/cache"]
EXPOSE 8088

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8088/health', timeout=5).read()" || exit 1

CMD ["uvicorn", "jm_server.app:app", "--host", "0.0.0.0", "--port", "8088"]
