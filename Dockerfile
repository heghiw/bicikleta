FROM python:3.9-slim

WORKDIR /app

COPY . /app

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8000

ENV SECRET_KEY="change-me-in-production"
ENV DATABASE_URL="sqlite:///./bikeapp.db"
ENV UPLOAD_DIR="data/uploads"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
