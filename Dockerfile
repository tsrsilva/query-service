FROM python:3.11-slim

# Install Java (required for Scala JAR)
RUN apt-get update && apt-get install -y --no-install-recommends default-jre-headless curl && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Download materializer release
RUN mkdir -p /app/tools && \
    curl -L -o /tmp/materializer.tgz \
    https://github.com/balhoff/materializer/releases/download/v0.2.7/materializer-0.2.7.tgz && \
    tar -xzf /tmp/materializer.tgz -C /app/tools && \
    rm /tmp/materializer.tgz

# Make script executable
RUN chmod +x /app/tools/materializer-0.2.7/bin/materializer

# Copy source code
COPY src/ ./src/
COPY queries/ ./queries/
COPY config/ ./config/

# Default command
CMD ["python", "src/main.py"]