FROM python:3.15.0-slim-bookworm@sha256:0e019bbdfb5d9874cb2389f1c2884b64aa2ac97c99960b5bc521cef978c0617d
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
