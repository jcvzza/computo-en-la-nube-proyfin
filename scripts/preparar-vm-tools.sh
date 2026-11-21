#!/usr/bin/env bash
#prepara vm-tools para el despliegue y el monitoreo: node_exporter, kubectl y docker compose
#se corre una sola vez dentro de vm-tools, desde la carpeta del repo clonado:
#  git clone https://github.com/jcvzza/computo-en-la-nube-proyfin.git && cd computo-en-la-nube-proyfin
#  bash scripts/preparar-vm-tools.sh
set -euo pipefail

KUBECTL_VERSION="v1.30.4"

echo "==> instalamos node_exporter (metricas de la vm en el puerto 9100) y docker compose"
sudo apt-get update -q
sudo apt-get install -y -q prometheus-node-exporter docker-compose-v2
sudo systemctl enable --now prometheus-node-exporter

echo "==> instalamos kubectl $KUBECTL_VERSION verificando su checksum"
cd /tmp
curl -fsSLO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
curl -fsSLO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl kubectl.sha256
cd - >/dev/null
kubectl version --client

echo "==> carpeta de secretos y .env del monitoreo (fuera del repo)"
mkdir -p monitoreo/secrets && chmod 700 monitoreo/secrets
[ -f monitoreo/.env ] || cp monitoreo/.env.example monitoreo/.env
chmod 600 monitoreo/.env

echo
echo "listo. pasos que siguen (ver README, seccion 'Puesta en marcha'):"
echo "  1. copiar k8s-token y k8s-ca.crt de vm-k8s a monitoreo/secrets/"
echo "  2. poner la url del webhook de discord en monitoreo/secrets/discord-webhook"
echo "  3. poner la contrasena de grafana en monitoreo/.env"
echo "  4. cd monitoreo && sudo docker compose up -d"
