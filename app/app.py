import os
import random
import time
from datetime import datetime

from flask import Flask, Response, render_template, request
from prometheus_client import Counter, Gauge, Histogram, generate_latest

app = Flask(__name__)

PAGE_VISITS = Counter(
    "telematica_page_visits_total",
    "Total de visitas por ruta",
    ["path", "method", "status"],
)
REQUEST_LATENCY = Histogram(
    "telematica_request_latency_seconds",
    "Latencia de respuesta",
    ["path"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5],
)
ACTIVE_USERS = Gauge(
    "telematica_active_users",
    "Usuarios activos estimados",
)
ERRORS_TOTAL = Counter(
    "telematica_errors_total",
    "Total de errores HTTP",
    ["path", "status"],
)


@app.before_request
def before_request():
    request.start_time = time.time()


@app.after_request
def after_request(response):
    path = request.path
    elapsed = time.time() - request.start_time
    if path != "/metrics":
        REQUEST_LATENCY.labels(path=path).observe(elapsed)
        PAGE_VISITS.labels(
            path=path, method=request.method, status=response.status_code
        ).inc()
        if response.status_code >= 400:
            ERRORS_TOTAL.labels(path=path, status=response.status_code).inc()
    ACTIVE_USERS.set(random.randint(1, 30))
    return response


@app.route("/")
def home():
    return render_template("index.html", year=datetime.now().year)


@app.route("/about")
def about():
    return render_template("about.html", year=datetime.now().year)


@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype="text/plain; version=0.0.4")


@app.route("/health")
def health():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port)
