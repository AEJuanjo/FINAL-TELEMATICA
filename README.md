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
5. Copia todo el bloque de credenciales que aparece

### 2. Configurar las credenciales

Abre una terminal y ejecuta:

**Mac / Linux:**
```bash
mkdir -p ~/.aws
nano ~/.aws/credentials
```

**Windows (PowerShell):**
```powershell
mkdir $HOME\.aws
notepad $HOME\.aws\credentials
```

Pega el bloque copiado de AWS Academy. Debe verse así:
```
[default]
aws_access_key_id=ASIA...
aws_secret_access_key=xxxxxxxx
aws_session_token=FwoGZX...
```

Guarda y cierra. Verifica que funcione:
```bash
aws sts get-caller-identity
```

### 3. Desplegar con Terraform

```bash
cd terraform

terraform init

terraform apply
```

Cuando pregunte `Do you want to perform these actions?` escribe **yes** y presiona Enter.

Al finalizar verás las URLs:

```
app_url        = "http://XX.XX.XX.XX"
grafana_url    = "http://XX.XX.XX.XX:3000"
prometheus_url = "http://XX.XX.XX.XX:9090"
```

### 4. Esperar 3-4 minutos

La instancia necesita ese tiempo para instalar Docker, clonar el proyecto y levantar los contenedores automáticamente.

### 5. Abrir en el navegador

| Servicio    | URL                  | Credenciales     |
|-------------|----------------------|------------------|
| Aplicación  | `http://<IP>`        | —                |
| Grafana     | `http://<IP>:3000`   | admin / admin123 |
| Prometheus  | `http://<IP>:9090`   | —                |

El dashboard **"Final Telemática — Monitoreo"** aparece automáticamente en Grafana bajo la carpeta **Monitoreo**.

---

## Destruir la infraestructura

```bash
cd terraform
terraform destroy
```

Escribe **yes** cuando lo pida.

---

## Estructura del proyecto

```
FINAL-TELEMATICA/
├── docker-compose.yml
├── README.md
├── app/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py
│   └── templates/
│       ├── index.html
│       └── about.html
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus.yml
│   └── grafana/
│       ├── dashboards/
│       │   └── final-telematica.json
│       └── provisioning/
│           ├── datasources/prometheus.yml
│           └── dashboards/dashboards.yml
└── terraform/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```
