# A imagem base é parametrizável para permitir o uso de um espelho do registro
# público e a fixação por digest:
#   docker build --build-arg BASE_IMAGE=python:3.12-slim@sha256:<digest> .
ARG BASE_IMAGE=python:3.12-slim
FROM ${BASE_IMAGE}

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

COPY requirements.txt .
RUN pip install --require-hashes -r requirements.txt

COPY app ./app

# Cadeia de certificação do banco gerenciado, usada com DB_SSLMODE=verify-full.
ADD https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /etc/ssl/certs/rds-global-bundle.pem
RUN chmod 444 /etc/ssl/certs/rds-global-bundle.pem

USER 10001:10001

EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import sys, urllib.request; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"]

# --no-access-log: o log de acesso é emitido pela aplicação em JSON, com request_id.
# --timeout-graceful-shutdown: conclui requisições em andamento ao receber SIGTERM.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log", "--timeout-graceful-shutdown", "20"]
