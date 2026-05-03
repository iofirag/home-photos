FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .
COPY templates/ ./templates/

# Create data directory for config output
RUN mkdir -p /data/immichframe/Config

# Expose port
EXPOSE 8081

# Set environment variable for ImmichFrame config directory
ENV IMMICHFRAME_CONFIG_DIR=/data/immichframe/Config

# Run the app
CMD ["python", "app.py"]
