FROM python:3.12.11-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY app.py .

RUN chmod +x app.py

CMD ["python3.12", "app.py"] 
