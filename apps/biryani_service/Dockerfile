FROM python:3.11-slim

WORKDIR /app

# Copy generic requirements
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Copy service specific code
COPY apps/biryani_service/ ./biryani_service/

EXPOSE 8000

CMD ["uvicorn", "biryani_service.main:app", "--host", "0.0.0.0", "--port", "8000"]
