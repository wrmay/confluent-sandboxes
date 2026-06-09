FROM python:3.12-slim AS builder

WORKDIR /app

RUN pip install --no-cache-dir poetry

COPY pyproject.toml  /app/
COPY *.avsc *.py /app/
RUN poetry install

CMD ["poetry", "run", "python", "-m", "event_generator"]
