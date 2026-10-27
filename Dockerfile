FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies first so Docker can cache this layer
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy only what the app needs at runtime
COPY app.py .
COPY templates/ templates/

# The pipeline passes the commit ID in; shown in the app's info panel
ARG GIT_COMMIT=local
ENV GIT_COMMIT=$GIT_COMMIT

# Run as a non-root user
RUN useradd --create-home appuser
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

# One worker because tasks are stored in memory; threads handle concurrency
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--threads", "4", "--access-logfile", "-", "app:app"]