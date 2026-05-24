# Final Telemática — Monitoreo con Flask, Prometheus y Grafana

Aplicación web desplegada automáticamente en AWS EC2 con Terraform.  
Stack: **Flask · Prometheus · Grafana · Docker · Terraform · AWS**

---

## Requisitos

Tener instalado en tu máquina:

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.2.0
- [AWS CLI](https://aws.amazon.com/cli/)

---

## Pasos para desplegar

### 1. Iniciar el lab en AWS Academy

1. Entra a [AWS Academy](https://awsacademy.instructure.com)
2. Abre tu curso → **Módulos** → **Learner Lab**
3. Haz clic en **Start Lab** y espera a que el círculo quede en verde
4. Haz clic en **AWS Details** → **AWS CLI**
5. Copia el bloque de credenciales que aparece, luce así:

```
[default]
aws_access_key_id = ASIA...
aws_secret_access_key = xxxxxxxx
aws_session_token = FwoGZX...
```

### 2. Configurar las credenciales en tu máquina

Pega las credenciales copiadas en el archivo `~/.aws/credentials`:

**Mac / Linux:**
```bash
nano ~/.aws/credentials
```

**Windows (PowerShell):**
```powershell
notepad $HOME\.aws\credentials
```

Reemplaza todo el contenido del archivo con las credenciales copiadas y guarda.

### 3. Desplegar con Terraform
cd terraform

terraform init

terraform apply
```

Cuando pregunte `Do you want to perform these actions?` escribe **yes** y presiona Enter.

Al finalizar verás las URLs en el output:

```
app_url        = "http://XX.XX.XX.XX"
grafana_url    = "http://XX.XX.XX.XX:3000"
prometheus_url = "http://XX.XX.XX.XX:9090"
nota           = "Espera 2-3 minutos para que Docker termine de levantar los contenedores."
```

### 4. Esperar 2-3 minutos

La instancia necesita ese tiempo para instalar Docker y levantar los contenedores automáticamente.

### 5. Abrir en el navegador

| Servicio    | URL                            | Credenciales         |
|-------------|--------------------------------|----------------------|
| Aplicación  | `http://<IP>`                  | —                    |
| Grafana     | `http://<IP>:3000`             | admin / admin123     |
| Prometheus  | `http://<IP>:9090`             | —                    |

El dashboard **"Final Telemática — Monitoreo"** aparece automáticamente en Grafana bajo la carpeta **Monitoreo**.

---

## Destruir la infraestructura

Cuando termines, elimina los recursos para no gastar créditos:

```bash
cd terraform
terraform destroy
```

Escribe **yes** cuando lo pida.

---

## Probar localmente (sin AWS)

Si solo quieres ver la app correr en tu máquina necesitas tener Docker instalado:

```bash
docker compose up --build -d
```

- App → http://localhost
- Grafana → http://localhost:3000 (admin / admin123)
- Prometheus → http://localhost:9090

Para detener:
```bash
docker compose down
```

---

## Estructura del proyecto

```
final-telematica/
├── docker-compose.yml
├── README.md
├── app/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py                   ← Flask + métricas Prometheus
│   └── templates/
│       ├── index.html
│       └── about.html
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus.yml       ← configuración de scraping
│   └── grafana/
│       ├── dashboards/
│       │   └── final-telematica.json
│       └── provisioning/
│           ├── datasources/
│           │   └── prometheus.yml
│           └── dashboards/
│               └── dashboards.yml
└── terraform/
    ├── main.tf                  ← EC2 + Security Group + user_data
    ├── variables.tf
    └── outputs.tf
```

## Métricas que expone la app

| Métrica | Tipo | Descripción |
|---|---|---|
| `telematica_page_visits_total` | Counter | Visitas por ruta y método HTTP |
| `telematica_request_latency_seconds` | Histogram | Latencia de respuesta en segundos |
| `telematica_active_users` | Gauge | Usuarios activos estimados |
| `telematica_errors_total` | Counter | Errores HTTP (4xx / 5xx) |
