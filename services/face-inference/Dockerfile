FROM python:3.15.2-slim-bookworm@sha256:96599df822d0e1c6bb700014a05c7f3c8cabc6e0f7ff3c4f9f69cee033b4b5d9
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.lock ./
RUN pip install --no-cache-dir --require-hashes -r requirements.lock
COPY model-manifest.json fetch_models.py LICENSE-detector LICENSE-recognizer ./
RUN python fetch_models.py && useradd --uid 10001 --no-create-home face
COPY inference.py server.py protocol.py ./
USER 10001
EXPOSE 8080
CMD ["python", "server.py"]
