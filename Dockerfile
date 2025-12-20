# --- ÉTAPE 1 : BUILDER ---
FROM python:3.11-slim-bookworm AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Installation des outils de build (gcc est nécessaire pour compiler certaines libs Python)
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt


# --- ÉTAPE 2 : RUNNER ---
FROM python:3.11-slim-bookworm AS runner

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    FLASK_APP=web/app.py

WORKDIR /app

# Installation de Ghostscript pour le runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends ghostscript \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Récupération de l'environnement virtuel et du code
COPY --from=builder /opt/venv /opt/venv
COPY web/ ./web/

RUN if ! id -u 1000 >/dev/null 2>&1; then \
        useradd -m -u 1000 appuser; \
    fi && \
    chown -R 1000:1000 /app

USER 1000

EXPOSE 5000

CMD ["gunicorn", "--workers=2", "--threads=4", "--timeout=120", "--bind=0.0.0.0:5000", "web.app:app"]
