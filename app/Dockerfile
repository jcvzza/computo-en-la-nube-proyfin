#etapa 1: instalamos las dependencias
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

#etapa 2: imagen final, solo con lo necesario para correr
FROM python:3.12-slim
#el pipeline inyecta estos valores con --build-arg
ARG APP_VERSION=0.0.0
ARG GIT_SHA=dev
ARG BUILD_DATE=desconocida
ENV APP_VERSION=$APP_VERSION GIT_SHA=$GIT_SHA BUILD_DATE=$BUILD_DATE HOST=0.0.0.0

#creamos un usuario sin privilegios para no correr como root
RUN useradd --uid 10001 --no-create-home appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app.py .

USER 10001
EXPOSE 8080
CMD ["python", "app.py"]
