# Secreto para descargar la imagen de GHCR

Solo hace falta si el paquete `medisur-app` en GHCR es privado. Se crea directo en el clúster, nunca en el repo:

```bash
kubectl -n medisur create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<usuario de github> \
  --docker-password=<token con read:packages>
```
