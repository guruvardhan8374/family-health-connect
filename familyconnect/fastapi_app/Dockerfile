FROM python:3.11-slim

WORKDIR /app

# FastAPI needs to access the Django settings if it uses the ORM
ENV DJANGO_SETTINGS_MODULE=familyconnect.settings
ENV PYTHONPATH=/app/..

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the entire backend folder to allow FastAPI to import from sibling apps
COPY . .

EXPOSE 8001

CMD ["uvicorn", "main:socket_app", "--host", "0.0.0.0", "--port", "8001"]
