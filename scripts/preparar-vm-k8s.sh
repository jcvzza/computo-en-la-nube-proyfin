#!/usr/bin/env bash
#prepara vm-k8s: node_exporter, k3s, cuentas de jenkins y prometheus, kube-state-metrics
#se corre una sola vez dentro de vm-k8s, desde la carpeta del repo clonado:
#  git clone https://github.com/jcvzza/computo-en-la-nube-proyfin.git && cd computo-en-la-nube-proyfin
#  bash scripts/preparar-vm-k8s.sh
set -euo pipefail

K3S_VERSION="v1.30.4+k3s1"
IP_PRIVADA="$(hostname -I | awk '{print $1}')"
SALIDA="$HOME/para-vm-tools"
K="sudo k3s kubectl"

echo "==> instalamos node_exporter (metricas de la vm en el puerto 9100)"
sudo apt-get update -q
sudo apt-get install -y -q prometheus-node-exporter
sudo systemctl enable --now prometheus-node-exporter

echo "==> instalamos k3s $K3S_VERSION (sin traefik ni metrics-server para ahorrar memoria)"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - server \
  --disable traefik --disable metrics-server \
  --tls-san "$IP_PRIVADA" --tls-san vm-k8s \
  --write-kubeconfig-mode 600

echo "==> esperamos a que el nodo este listo"
until $K get nodes 2>/dev/null | grep -q " Ready"; do sleep 3; done
$K get nodes

echo "==> namespace de la app, cuenta de jenkins y monitoreo"
$K apply -f k8s/namespace.yaml
$K apply -f k8s/acceso/jenkins.yaml
$K apply -f monitoreo/k8s/kube-state-metrics.yaml -f monitoreo/k8s/prometheus-acceso.yaml
$K -n kube-system rollout status deployment/kube-state-metrics --timeout=180s

echo "==> secreto de la app con un valor aleatorio (nunca se escribe en el repo)"
if ! $K -n medisur get secret medisur-secret >/dev/null 2>&1; then
  $K -n medisur create secret generic medisur-secret --from-literal=SECRET_KEY="$(openssl rand -hex 32)"
fi

echo "==> generamos los archivos que necesita vm-tools en $SALIDA"
until $K -n medisur get secret jenkins-token -o jsonpath='{.data.token}' 2>/dev/null | grep -q .; do sleep 2; done
until $K -n monitoreo get secret prometheus-token -o jsonpath='{.data.token}' 2>/dev/null | grep -q .; do sleep 2; done
mkdir -p "$SALIDA" && chmod 700 "$SALIDA"
#el archivo lo escribe el usuario (no root) a proposito, por eso la redireccion queda fuera de sudo
# shellcheck disable=SC2024
sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml bash scripts/generar-kubeconfig.sh medisur jenkins-token "https://$IP_PRIVADA:6443" > "$SALIDA/kubeconfig-jenkins.yaml"
$K -n monitoreo get secret prometheus-token -o jsonpath='{.data.token}' | base64 -d > "$SALIDA/k8s-token"
$K -n monitoreo get secret prometheus-token -o jsonpath='{.data.ca\.crt}' | base64 -d > "$SALIDA/k8s-ca.crt"
chmod 600 "$SALIDA"/*

echo
echo "listo. en $SALIDA quedaron 3 archivos (son secretos, no se suben al repo ni se mandan por chat):"
ls -l "$SALIDA"
echo "  kubeconfig-jenkins.yaml -> credencial 'kubeconfig-k3s' (Secret file) en jenkins"
echo "  k8s-token y k8s-ca.crt  -> monitoreo/secrets/ en vm-tools"
