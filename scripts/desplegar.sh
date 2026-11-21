#!/usr/bin/env bash
#despliega una version de la app en kubernetes y verifica que quedo bien
#uso: scripts/desplegar.sh <imagen> <sha_corto> <version> <url_de_la_app>
#necesita KUBECONFIG apuntando al cluster (en jenkins sale de las credenciales)
set -euo pipefail

IMAGEN="$1"
SHA="$2"
VERSION="$3"
URL="$4"
NS=medisur
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> desplegamos $IMAGEN:$SHA (version $VERSION)"

#aplicamos namespace, configmap y service tal cual
kubectl apply -f "$RAIZ/k8s/namespace.yaml"
kubectl apply -f "$RAIZ/k8s/configmap.yaml" -f "$RAIZ/k8s/service.yaml"

#ponemos la imagen exacta (sha) y la version en el deployment y lo aplicamos
sed -e "s|__IMAGEN__|$IMAGEN:$SHA|" -e "s|__VERSION__|$VERSION|" "$RAIZ/k8s/deployment.yaml" | kubectl apply -f -

#dejamos anotado el motivo del cambio para verlo en kubectl rollout history
kubectl -n "$NS" annotate deployment/medisur-app \
  kubernetes.io/change-cause="version $VERSION sha $SHA" --overwrite

#esperamos a que la actualizacion gradual termine, si no termina a tiempo falla
kubectl -n "$NS" rollout status deployment/medisur-app --timeout="${ROLLOUT_TIMEOUT:-180s}"

#prueba de humo: /health debe responder y /version debe traer el sha que acabamos de desplegar
echo "==> prueba de humo contra $URL"
for i in $(seq 1 10); do
  if curl -fsS --max-time 3 "$URL/health" > /dev/null; then break; fi
  echo "    /health todavia no responde (intento $i)"; sleep 3
  [ "$i" = 10 ] && { echo "ERROR: /health no respondio"; exit 1; }
done
RESPUESTA="$(curl -fsS --max-time 3 "$URL/version")"
echo "    /version -> $RESPUESTA"
echo "$RESPUESTA" | grep -q "\"sha\":\"$SHA\"" || { echo "ERROR: /version no trae el sha $SHA"; exit 1; }

echo "==> despliegue correcto: version $VERSION sha $SHA"
