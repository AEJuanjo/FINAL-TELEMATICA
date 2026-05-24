terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# AMI: Amazon Linux 2023 (siempre la más reciente)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group: abre los puertos necesarios
resource "aws_security_group" "telematica_sg" {
  name        = "telematica-sg"
  description = "Acceso web, Grafana, Prometheus y SSH"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Aplicacion web"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "telematica-sg"
  }
}

# EC2: instala Docker y despliega el proyecto automaticamente
resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.telematica_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  # Este script corre automaticamente al iniciar la instancia.
  # Instala Docker, copia el proyecto y levanta docker compose.
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    # 1. Instalar Docker
    dnf update -y
    dnf install -y docker docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    # 2. Crear directorio del proyecto
    mkdir -p /opt/telematica
    cd /opt/telematica

    # 3. Crear estructura de carpetas
    mkdir -p app/templates \
             monitoring/prometheus \
             monitoring/grafana/dashboards \
             monitoring/grafana/provisioning/datasources \
             monitoring/grafana/provisioning/dashboards

    # 4. Escribir los archivos del proyecto

    cat > app/requirements.txt << 'PYEOF'
flask==3.0.3
prometheus-client==0.20.0
PYEOF

    cat > app/Dockerfile << 'DEOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
DEOF

    cat > app/app.py << 'APPEOF'
import os, random, time
from datetime import datetime
from flask import Flask, Response, render_template, request
from prometheus_client import Counter, Gauge, Histogram, generate_latest

app = Flask(__name__)

PAGE_VISITS = Counter("telematica_page_visits_total", "Visitas", ["path", "method", "status"])
REQUEST_LATENCY = Histogram("telematica_request_latency_seconds", "Latencia", ["path"])
ACTIVE_USERS = Gauge("telematica_active_users", "Usuarios activos")
ERRORS_TOTAL = Counter("telematica_errors_total", "Errores", ["path", "status"])

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    path = request.path
    elapsed = time.time() - request.start_time
    if path != "/metrics":
        REQUEST_LATENCY.labels(path=path).observe(elapsed)
        PAGE_VISITS.labels(path=path, method=request.method, status=response.status_code).inc()
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
    return {"status": "ok"}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")))
APPEOF

    cat > app/templates/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"/><title>Final Telematica</title>
<style>
body{font-family:system-ui,sans-serif;background:#0f172a;color:#e2e8f0;margin:0;min-height:100vh}
header{background:linear-gradient(135deg,#1e3a5f,#0f172a);padding:1rem 2rem;border-bottom:1px solid #1e40af44;display:flex;justify-content:space-between;align-items:center}
header h1{color:#60a5fa;font-size:1.4rem}
nav a{color:#94a3b8;text-decoration:none;margin-left:1.5rem}
nav a:hover{color:#60a5fa}
.hero{text-align:center;padding:5rem 2rem 3rem}
.hero h2{font-size:2.5rem;font-weight:700;background:linear-gradient(90deg,#60a5fa,#a78bfa);-webkit-background-clip:text;-webkit-text-fill-color:transparent;margin-bottom:1rem}
.hero p{color:#94a3b8;max-width:520px;margin:0 auto 2rem}
.badges{display:flex;justify-content:center;gap:.75rem;flex-wrap:wrap;margin-bottom:2rem}
.badge{background:#1e293b;border:1px solid #334155;border-radius:9999px;padding:.3rem 1rem;font-size:.8rem;color:#60a5fa}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:1.25rem;max-width:800px;margin:0 auto;padding:0 2rem 4rem}
.card{background:#1e293b;border:1px solid #334155;border-radius:1rem;padding:1.5rem}
.card:hover{border-color:#3b82f6}
.card-icon{font-size:2rem;margin-bottom:.75rem}
.card h3{margin-bottom:.4rem}
.card p{font-size:.85rem;color:#64748b;line-height:1.5}
footer{text-align:center;padding:1.5rem;color:#475569;font-size:.8rem;border-top:1px solid #1e293b}
</style>
</head>
<body>
<header><h1>📡 Final Telematica</h1><nav><a href="/">Inicio</a><a href="/about">Acerca de</a><a href="/health">Health</a></nav></header>
<section class="hero">
  <h2>Monitoreo en tiempo real</h2>
  <p>Proyecto final de Telematica — infraestructura desplegada en AWS con observabilidad completa.</p>
  <div class="badges">
    <span class="badge">🐍 Flask</span><span class="badge">📊 Prometheus</span>
    <span class="badge">📈 Grafana</span><span class="badge">🐳 Docker</span>
    <span class="badge">☁️ AWS EC2</span><span class="badge">🏗️ Terraform</span>
  </div>
</section>
<div class="cards">
  <div class="card"><div class="card-icon">🔭</div><h3>Observabilidad</h3><p>Metricas de visitas, latencia y usuarios en /metrics.</p></div>
  <div class="card"><div class="card-icon">📊</div><h3>Grafana</h3><p>Dashboard preconfigurado. Puerto 3000.</p></div>
  <div class="card"><div class="card-icon">☁️</div><h3>AWS + Terraform</h3><p>EC2 provisionada automaticamente con IaC.</p></div>
</div>
<footer>© {{ year }} Final Telematica</footer>
</body></html>
HTMLEOF

    cat > app/templates/about.html << 'ABOUTEOF'
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"/><title>Acerca de</title>
<style>body{font-family:system-ui,sans-serif;background:#0f172a;color:#e2e8f0;margin:0}header{background:linear-gradient(135deg,#1e3a5f,#0f172a);padding:1rem 2rem;border-bottom:1px solid #1e40af44;display:flex;justify-content:space-between;align-items:center}header h1{color:#60a5fa;font-size:1.4rem}nav a{color:#94a3b8;text-decoration:none;margin-left:1.5rem}.content{max-width:700px;margin:4rem auto;padding:0 2rem}h2{color:#60a5fa;margin-bottom:1rem}p{color:#94a3b8;line-height:1.7;margin-bottom:1rem}.stack{display:flex;flex-wrap:wrap;gap:.75rem;margin-top:1.5rem}.tag{background:#1e293b;border:1px solid #334155;border-radius:.5rem;padding:.4rem .9rem;font-size:.85rem;color:#60a5fa}</style>
</head>
<body>
<header><h1>📡 Final Telematica</h1><nav><a href="/">Inicio</a><a href="/about">Acerca de</a></nav></header>
<div class="content">
  <h2>Acerca del proyecto</h2>
  <p>Proyecto final del curso de Telematica. Implementa una aplicacion web con observabilidad completa desplegada en AWS con Terraform.</p>
  <div class="stack">
    <span class="tag">Python 3.12</span><span class="tag">Flask</span><span class="tag">prometheus-client</span>
    <span class="tag">Docker Compose</span><span class="tag">Prometheus</span><span class="tag">Grafana</span>
    <span class="tag">Terraform</span><span class="tag">AWS EC2</span>
  </div>
</div>
</body></html>
ABOUTEOF

    cat > monitoring/prometheus/prometheus.yml << 'PROMEOF'
global:
  scrape_interval: 5s
  evaluation_interval: 5s

scrape_configs:
  - job_name: "app-flask"
    metrics_path: "/metrics"
    static_configs:
      - targets: ["app:5000"]
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
PROMEOF

    cat > monitoring/grafana/provisioning/datasources/prometheus.yml << 'DSEOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
DSEOF

    cat > monitoring/grafana/provisioning/dashboards/dashboards.yml << 'DBEOF'
apiVersion: 1
providers:
  - name: "Telematica"
    orgId: 1
    folder: "Monitoreo"
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
DBEOF

    cat > monitoring/grafana/dashboards/final-telematica.json << 'JSONEOF'
{"annotations":{"list":[]},"editable":true,"graphTooltip":1,"id":null,"panels":[{"datasource":{"type":"prometheus","uid":"prometheus"},"fieldConfig":{"defaults":{"color":{"mode":"thresholds"},"thresholds":{"mode":"absolute","steps":[{"color":"green","value":null}]},"unit":"reqps"}},"gridPos":{"h":4,"w":6,"x":0,"y":0},"id":1,"options":{"colorMode":"background","graphMode":"area","reduceOptions":{"calcs":["lastNotNull"]},"textMode":"auto"},"title":"Visitas / segundo","type":"stat","targets":[{"datasource":{"type":"prometheus","uid":"prometheus"},"expr":"sum(rate(telematica_page_visits_total[1m]))","legendFormat":"req/s","refId":"A"}]},{"datasource":{"type":"prometheus","uid":"prometheus"},"fieldConfig":{"defaults":{"color":{"mode":"thresholds"},"thresholds":{"mode":"absolute","steps":[{"color":"green","value":null},{"color":"yellow","value":10},{"color":"red","value":25}]},"unit":"none"}},"gridPos":{"h":4,"w":6,"x":6,"y":0},"id":2,"options":{"colorMode":"background","graphMode":"none","reduceOptions":{"calcs":["lastNotNull"]},"textMode":"auto"},"title":"Usuarios activos","type":"stat","targets":[{"datasource":{"type":"prometheus","uid":"prometheus"},"expr":"telematica_active_users","legendFormat":"usuarios","refId":"A"}]},{"datasource":{"type":"prometheus","uid":"prometheus"},"fieldConfig":{"defaults":{"color":{"mode":"thresholds"},"thresholds":{"mode":"absolute","steps":[{"color":"green","value":null},{"color":"yellow","value":0.2},{"color":"red","value":0.5}]},"unit":"s"}},"gridPos":{"h":4,"w":6,"x":12,"y":0},"id":3,"options":{"colorMode":"background","graphMode":"none","reduceOptions":{"calcs":["lastNotNull"]},"textMode":"auto"},"title":"Latencia p95","type":"stat","targets":[{"datasource":{"type":"prometheus","uid":"prometheus"},"expr":"histogram_quantile(0.95, sum(rate(telematica_request_latency_seconds_bucket[5m])) by (le))","legendFormat":"p95","refId":"A"}]},{"datasource":{"type":"prometheus","uid":"prometheus"},"fieldConfig":{"defaults":{"color":{"mode":"palette-classic"},"custom":{"lineWidth":2,"fillOpacity":10},"unit":"reqps"}},"gridPos":{"h":8,"w":12,"x":0,"y":4},"id":10,"options":{"legend":{"calcs":["mean","max"],"displayMode":"table","placement":"bottom"},"tooltip":{"mode":"multi"}},"title":"Trafico por ruta (req/s)","type":"timeseries","targets":[{"datasource":{"type":"prometheus","uid":"prometheus"},"expr":"sum by (path) (rate(telematica_page_visits_total[1m]))","legendFormat":"{{ path }}","refId":"A"}]},{"datasource":{"type":"prometheus","uid":"prometheus"},"fieldConfig":{"defaults":{"color":{"mode":"palette-classic"},"custom":{"lineWidth":2,"fillOpacity":10},"unit":"s"}},"gridPos":{"h":8,"w":12,"x":12,"y":4},"id":11,"options":{"legend":{"calcs":["mean","max"],"displayMode":"table","placement":"bottom"},"tooltip":{"mode":"multi"}},"title":"Latencia p50 / p95 / p99","type":"timeseries","targets":[{"datasource":{"type":"prometheus","uid":"prometheus"},"expr":"histogram_quantile(0.50, sum(rate(telematica_request_latency_seconds_bucket[5m])) by (le))","legendFormat":"p50","refId":"A"},{"datasource":{"type":"prometheus","uid":"prometheus"},"expr":"histogram_quantile(0.95, sum(rate(telematica_request_latency_seconds_bucket[5m])) by (le))","legendFormat":"p95","refId":"B"},{"datasource":{"type":"prometheus","uid":"prometheus"},"expr":"histogram_quantile(0.99, sum(rate(telematica_request_latency_seconds_bucket[5m])) by (le))","legendFormat":"p99","refId":"C"}]}],"refresh":"5s","schemaVersion":39,"tags":["telematica"],"time":{"from":"now-30m","to":"now"},"timezone":"browser","title":"Final Telematica - Monitoreo","uid":"final-telematica","version":1}
JSONEOF

    cat > docker-compose.yml << 'COMPOSEEOF'
services:
  app:
    build:
      context: ./app
    container_name: telematica-app
    ports:
      - "80:5000"
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:v2.53.0
    container_name: telematica-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
    depends_on:
      - app
    restart: unless-stopped

  grafana:
    image: grafana/grafana:11.1.0
    container_name: telematica-grafana
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin123
      GF_USERS_ALLOW_SIGN_UP: "false"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning:ro
      - ./monitoring/grafana/dashboards:/var/lib/grafana/dashboards:ro
    depends_on:
      - prometheus
    restart: unless-stopped

volumes:
  prometheus-data:
  grafana-data:
COMPOSEEOF

    # 5. Levantar el proyecto
    cd /opt/telematica
    docker compose up --build -d

    echo "Despliegue completado: $(date)" > /opt/telematica/deploy.log
  EOF

  tags = {
    Name = "telematica-app-server"
  }
}
