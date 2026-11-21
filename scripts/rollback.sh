#!/usr/bin/env bash
#regresa el deployment a la version anterior y espera a que quede estable
#jenkins lo llama solo si el despliegue o la prueba de humo fallaron
set -euo pipefail
NS=medisur

echo "==> rollback: regresamos a la version anterior"
kubectl -n "$NS" rollout undo deployment/medisur-app
kubectl -n "$NS" rollout status deployment/medisur-app --timeout="${ROLLOUT_TIMEOUT:-180s}"
kubectl -n "$NS" rollout history deployment/medisur-app | tail -5
