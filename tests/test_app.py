import pytest

import app as app_module
from app import app


@pytest.fixture
def client():
    app_module.tasks.clear()
    app_module._next_id = 1
    return app.test_client()


def test_home_page_loads(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"Task Manager" in response.data


def test_health_returns_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_info_contains_version_and_hostname(client):
    data = client.get("/api/info").get_json()
    assert data["version"] == app_module.VERSION
    assert data["hostname"]
    assert "uptime_seconds" in data


def test_tasks_empty_initially(client):
    assert client.get("/api/tasks").get_json() == []


def test_create_task(client):
    response = client.post("/api/tasks", json={"title": "Write report"})
    assert response.status_code == 201
    data = response.get_json()
    assert data["title"] == "Write report"
    assert data["done"] is False
    assert len(client.get("/api/tasks").get_json()) == 1


def test_create_task_rejects_empty_title(client):
    response = client.post("/api/tasks", json={"title": "   "})
    assert response.status_code == 400


def test_create_task_rejects_missing_body(client):
    response = client.post("/api/tasks")
    assert response.status_code == 400


def test_mark_task_done(client):
    task = client.post("/api/tasks", json={"title": "Deploy"}).get_json()
    response = client.put(f"/api/tasks/{task['id']}", json={"done": True})
    assert response.status_code == 200
    assert response.get_json()["done"] is True


def test_update_missing_task_returns_404(client):
    response = client.put("/api/tasks/999", json={"done": True})
    assert response.status_code == 404


def test_delete_task(client):
    task = client.post("/api/tasks", json={"title": "Temp"}).get_json()
    assert client.delete(f"/api/tasks/{task['id']}").status_code == 204
    assert client.get("/api/tasks").get_json() == []


def test_delete_missing_task_returns_404(client):
    assert client.delete("/api/tasks/999").status_code == 404
