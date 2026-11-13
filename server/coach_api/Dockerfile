# syntax=docker/dockerfile:1
# StrongSense coach API - production-ish image.
# Build from the repository root:
#   docker build -t strongsense-coach-api server/coach_api
# Run (mount your own .env, never bake keys into the image):
#   docker run --rm -p 8080:8080 --env-file server/coach_api/.env strongsense-coach-api

FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Dedicated unprivileged user; no build tools are installed at all.
RUN groupadd --system --gid 1001 coach \
    && useradd --system --uid 1001 --gid coach --create-home --shell /usr/sbin/nologin coach

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --no-compile -r /app/requirements.txt \
    && rm -f /app/requirements.txt

COPY app /app/app

ENV APP_ENV=production \
    COACH_HOST=0.0.0.0 \
    COACH_PORT=8080

USER coach

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import json,sys,urllib.request; r=urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=4); sys.exit(0 if r.status == 200 and json.load(r).get('status') == 'ok' else 1)"]

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
