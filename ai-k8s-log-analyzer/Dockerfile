# Use a lightweight python image
FROM python:3.11-slim

# Set work directory
WORKDIR /app

# Install system dependencies if any are needed
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy dependencies list
COPY requirements.txt .

# Install dependencies without cache
RUN pip install --no-cache-dir -r requirements.txt

# Copy application script
COPY main.py .

# Run as non-root user for security
RUN useradd -u 10001 appuser && chown -R appuser:appuser /app
USER appuser

# Entrypoint to run the analyzer script
ENTRYPOINT ["python", "main.py"]
