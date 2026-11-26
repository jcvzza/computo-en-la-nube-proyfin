import os
import signal
import time

from flask import Flask, jsonify, request, Response
from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

#leemos la version, el sha y la fecha desde variables de entorno, el pipeline las agrega al construir la imagen
APP_VERSION = os.getenv("APP_VERSION", "0.0.0")
GIT_SHA = os.getenv("GIT_SHA", "dev")
BUILD_DATE = os.getenv("BUILD_DATE", "desconocida")
#el entorno llega desde el configmap de kubernetes
ENTORNO = os.getenv("ENTORNO", "local")

#como es un piloto, guardamos los items en una lista en vez de usar base de datos
items = []

#declaramos las metricas que va a leer prometheus, una cuenta las peticiones y la otra mide cuanto tardan
peticiones = Counter("http_requests_total", "Total de peticiones", ["method", "path", "status"])
latencia = Histogram("http_request_duration_seconds", "Tiempo de respuesta", ["method", "path"])
#publicamos la version desplegada como etiqueta para mostrarla en grafana
info = Gauge("medisur_app_info", "Version desplegada de la app", ["version", "sha", "entorno"])
info.labels(APP_VERSION, GIT_SHA, ENTORNO).set(1)


@app.before_request
def empezar_tiempo():
    #guardamos la hora en la que llego la peticion
    request.inicio = time.time()


@app.after_request
def guardar_metricas(respuesta):
    #no contamos la ruta /metrics para que no se llene de ruido
    if request.path != "/metrics":
        #calculamos cuanto tardo la peticion y lo agregamos a las metricas
        duracion = time.time() - request.inicio
        latencia.labels(request.method, request.path).observe(duracion)
        peticiones.labels(request.method, request.path, respuesta.status_code).inc()
    return respuesta


@app.route("/health")
def health():
    #sirve para verificar que la app esta viva
    return jsonify(status="ok")


@app.route("/ready")
def ready():
    #sirve para verificar que la app ya puede recibir trafico
    return jsonify(status="ready")


@app.route("/version")
def version():
    #mostramos que version esta corriendo para comprobar que se actualizo
    return jsonify(version=APP_VERSION, sha=GIT_SHA, build_date=BUILD_DATE, entorno=ENTORNO, mensaje="demo en video ")


@app.route("/metrics")
def metrics():
    #prometheus lee las metricas desde esta ruta
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


@app.route("/api/items", methods=["GET"])
def listar_items():
    #regresamos todos los items que hemos guardado
    return jsonify(items)


@app.route("/api/items", methods=["POST"])
def crear_item():
    datos = request.get_json(silent=True)

    #verificamos que nos hayan mandado el nombre, si no regresamos un error
    if not datos or not datos.get("name"):
        return jsonify(error="Falta el campo name"), 400

    #creamos el item y lo agregamos a la lista
    item = {"id": len(items) + 1, "name": datos["name"]}
    items.append(item)
    return jsonify(item), 201


def apagar(signum, frame):
    #kubernetes manda sigterm al quitar un pod, salimos de inmediato en vez de esperar 30 s a que nos maten
    raise SystemExit(0)


def calcular_descuento(monto):
    #esta funcion es a proposito para la demo: tiene un bug y no tiene pruebas
    if monto == monto:
        return monto * 0.9
    return monto


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, apagar)
    app.run(host=os.getenv("HOST", "127.0.0.1"), port=8080)
