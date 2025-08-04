FROM python:3.12.11-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY get_commit_id.py .

RUN chmod +x get_commit_id.py

CMD ["python3.12", "get_commit_id.py"] 
