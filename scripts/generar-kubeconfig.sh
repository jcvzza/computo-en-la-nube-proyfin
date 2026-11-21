#!/usr/bin/env bash
#arma un kubeconfig con el token de una cuenta de servicio (sin permisos de administrador)
#uso: scripts/generar-kubeconfig.sh <namespace> <secreto_del_token> <url_del_api> > archivo
#necesita un KUBECONFIG de administrador para leer el token
set -euo pipefail
NS="$1"; SECRETO="$2"; API="$3"

TOKEN="$(kubectl -n "$NS" get secret "$SECRETO" -o jsonpath='{.data.token}' | base64 -d)"
CA="$(kubectl -n "$NS" get secret "$SECRETO" -o jsonpath='{.data.ca\.crt}')"

cat <<FIN
apiVersion: v1
kind: Config
clusters:
  - name: medisur
    cluster:
      server: $API
      certificate-authority-data: $CA
users:
  - name: $SECRETO
    user:
      token: $TOKEN
contexts:
  - name: medisur
    context:
      cluster: medisur
      user: $SECRETO
      namespace: $NS
current-context: medisur
FIN
