FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends tesseract-ocr tesseract-ocr-nld tesseract-ocr-eng && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY ocr-service/requirements.lock.txt .
RUN pip install --no-cache-dir -r requirements.lock.txt
COPY data/places.json /app/data/places.json
COPY ocr-service /app/ocr-service
RUN useradd --create-home --uid 10001 toporotor
USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/ready', timeout=3)"]
CMD ["uvicorn", "app:app", "--app-dir", "/app/ocr-service", "--host", "0.0.0.0", "--port", "8080", "--no-access-log"]
