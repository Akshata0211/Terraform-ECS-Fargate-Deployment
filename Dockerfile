FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Copy requirements file and install dependencies first
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

EXPOSE 5000

# Run the application
CMD ["python", "app.py"]