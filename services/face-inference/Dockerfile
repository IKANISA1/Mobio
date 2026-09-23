FROM python:3.12.13-slim-bookworm@sha256:4766d8b510c428e595d74b9cc5bbb2fae8e26316fffb4adc89908d79aacd58a2
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.lock ./
RUN pip install --no-cache-dir --require-hashes -r requirements.lock
COPY model-manifest.json fetch_models.py LICENSE-detector LICENSE-recognizer ./
RUN python fetch_models.py && useradd --uid 10001 --no-create-home face
COPY inference.py server.py ./
USER 10001
EXPOSE 8080
CMD ["python", "server.py"]
