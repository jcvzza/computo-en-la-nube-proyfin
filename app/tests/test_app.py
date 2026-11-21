import pytest

from app import app, apagar

#creamos un cliente de prueba para simular las peticiones sin levantar el servidor
cliente = app.test_client()


def test_health():
    #verificamos que la ruta health responda ok
    r = cliente.get("/health")
    assert r.status_code == 200
    assert r.get_json()["status"] == "ok"


def test_ready():
    #verificamos que la app este lista
    r = cliente.get("/ready")
    assert r.status_code == 200


def test_version():
    #verificamos que la respuesta traiga la version, el sha y la fecha
    r = cliente.get("/version")
    datos = r.get_json()
    assert "version" in datos
    assert "sha" in datos
    assert "build_date" in datos
    assert "entorno" in datos


def test_metrics():
    #hacemos una peticion primero para que ya existan metricas
    cliente.get("/health")
    r = cliente.get("/metrics")
    assert r.status_code == 200
    texto = r.get_data(as_text=True)
    assert "http_requests_total" in texto
    #verificamos que tambien salga la version desplegada
    assert "medisur_app_info" in texto


def test_crear_item():
    #creamos un item y verificamos que se haya guardado con el nombre correcto
    r = cliente.post("/api/items", json={"name": "gasas"})
    assert r.status_code == 201
    assert r.get_json()["name"] == "gasas"


def test_listar_items():
    #agregamos un item y verificamos que aparezca en la lista
    cliente.post("/api/items", json={"name": "jeringas"})
    r = cliente.get("/api/items")
    assert r.status_code == 200
    assert len(r.get_json()) >= 1


def test_crear_item_sin_nombre():
    #si no mandamos el nombre debe regresar error 400
    r = cliente.post("/api/items", json={})
    assert r.status_code == 400


def test_apagar():
    #verificamos que al recibir la senal de apagado la app termine limpio
    with pytest.raises(SystemExit):
        apagar(15, None)
