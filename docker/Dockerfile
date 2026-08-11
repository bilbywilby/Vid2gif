FROM python:3.11-slim

RUN apt-get update && apt-get install -y ffmpeg git && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY pyproject.toml README.md ./
COPY src/ src/
RUN pip install --no-cache-dir .

COPY docker/benchmark.sh /app/benchmark.sh
RUN chmod +x /app/benchmark.sh

ENTRYPOINT ["/app/benchmark.sh"]
