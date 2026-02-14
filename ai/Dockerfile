FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for Ollama
RUN apt-get update && apt-get install -y \
    curl \
    zstd \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama with error handling
RUN set -e && \
    curl -fsSL https://ollama.com/install.sh -o /tmp/install-ollama.sh && \
    chmod +x /tmp/install-ollama.sh && \
    /tmp/install-ollama.sh && \
    rm /tmp/install-ollama.sh && \
    echo "Checking Ollama installation..." && \
    (which ollama || find /usr/local -name ollama -type f 2>/dev/null | head -1) && \
    echo "Ollama installation completed"

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY backend/ ./backend/

# Copy start script
COPY start.sh ./
RUN sed -i 's/\r$//' start.sh && chmod +x start.sh

# Expose ports
# 8000 for FastAPI, 11434 for Ollama (internal only)
EXPOSE 8000

# Run start script which starts both Ollama and FastAPI
CMD ["./start.sh"]

