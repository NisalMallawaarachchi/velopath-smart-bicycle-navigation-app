# Node.js + Python runtime for VeloPath Backend
FROM node:20-slim

# Install Python and pip for ML hazard detection
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Create Python virtual environment and install ML dependencies
COPY ml/requirements.txt /tmp/requirements.txt
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir -r /tmp/requirements.txt

WORKDIR /app

# Install Node.js dependencies
COPY package.json package-lock.json ./
RUN npm ci --production

# Copy application code
COPY . .

# Expose port (Railway sets PORT automatically)
EXPOSE ${PORT:-5001}

CMD ["node", "server.js"]
