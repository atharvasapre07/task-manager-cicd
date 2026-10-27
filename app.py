import os
import socket
import threading
import time

from flask import Flask, jsonify, render_template, request

app = Flask(__name__)

# Bump this when you demonstrate a code change through the pipeline.
VERSION = "v1"
COMMIT = os.environ.get("GIT_COMMIT", "local")
START_TIME = time.time()

# In-memory storage (kept simple on purpose; resets when the container restarts).
_lock = threading.Lock()
tasks = []
_next_id = 1


def _find(task_id):
    return next((t for t in tasks if t["id"] == task_id), None)


@app.route("/")
def home():
    return render_template("index.html")


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/api/info")
def info():
    return jsonify(
        version=VERSION,
        commit=COMMIT,
        hostname=socket.gethostname(),
        uptime_seconds=int(time.time() - START_TIME),
        task_count=len(tasks),
    )


@app.route("/api/tasks", methods=["GET"])
def list_tasks():
    return jsonify(tasks)


@app.route("/api/tasks", methods=["POST"])
def create_task():
    global _next_id
    data = request.get_json(silent=True) or {}
    title = str(data.get("title", "")).strip()
    if not title:
        return jsonify(error="title is required"), 400
    if len(title) > 100:
        return jsonify(error="title must be 100 characters or fewer"), 400
    with _lock:
        task = {"id": _next_id, "title": title, "done": False}
        _next_id += 1
        tasks.append(task)
    return jsonify(task), 201


@app.route("/api/tasks/<int:task_id>", methods=["PUT"])
def update_task(task_id):
    data = request.get_json(silent=True) or {}
    with _lock:
        task = _find(task_id)
        if task is None:
            return jsonify(error="task not found"), 404
        if "done" in data:
            task["done"] = bool(data["done"])
        if "title" in data:
            title = str(data["title"]).strip()
            if not title:
                return jsonify(error="title cannot be empty"), 400
            task["title"] = title
    return jsonify(task)


@app.route("/api/tasks/<int:task_id>", methods=["DELETE"])
def delete_task(task_id):
    with _lock:
        task = _find(task_id)
        if task is None:
            return jsonify(error="task not found"), 404
        tasks.remove(task)
    return "", 204


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
