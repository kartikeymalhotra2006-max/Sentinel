FROM python:3.11-slim
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 PYTHONDONTWRITEBYTECODE=1
# LightGBM needs the OpenMP runtime
RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements-serve.txt .
RUN pip install -r requirements-serve.txt
COPY src ./src
COPY artifacts/bundle.joblib ./artifacts/bundle.joblib
ENV PYTHONPATH=/app/src SENTINEL_BUNDLE=/app/artifacts/bundle.joblib
RUN useradd -m app && chown -R app /app
USER app
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=3s --retries=3 CMD curl -fs http://localhost:8000/health || exit 1
# One worker per container keeps in-memory fallback state consistent; scale with REDIS_URL + replicas.
CMD ["uvicorn", "sentinel.serve.app:app", "--host", "0.0.0.0", "--port", "8000"]
