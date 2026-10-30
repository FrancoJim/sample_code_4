FROM python:3.14-slim
LABEL org.opencontainers.image.source="https://github.com/FrancoJim/sample_code_4"
LABEL org.opencontainers.image.licenses="MIT"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=5000 \
    GUNICORN_WORKERS=2

WORKDIR /app

COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    groupadd --system --gid 10001 app && \
    useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

# Only the app; tests and dev requirements stay out of the image
COPY src/app.py .

# Numeric UID so Kubernetes runAsNonRoot can verify it
USER 10001
EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ['PORT'] + '/health', timeout=2)"]

# gunicorn instead of Flask's development server
CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT} --workers ${GUNICORN_WORKERS} --access-logfile - app:app"]
