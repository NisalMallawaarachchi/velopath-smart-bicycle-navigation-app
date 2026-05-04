FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy service code + preprocess module from parent ml/ dir
COPY . .
COPY ../ml/preprocess.py ./preprocess.py
COPY ../ml/model.pkl     ./model.pkl

EXPOSE ${PORT:-8001}

CMD uvicorn main:app --host 0.0.0.0 --port ${PORT:-8001}
