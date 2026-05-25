output "instance_id" {
  description = "ID de la instancia EC2."
  value       = aws_instance.app_server.id
}

output "public_ip" {
  description = "IP publica de la instancia."
  value       = aws_instance.app_server.public_ip
}

output "app_url" {
  description = "URL de la aplicacion web."
  value       = "http://${aws_instance.app_server.public_ip}"
}

output "grafana_url" {
  description = "URL de Grafana (usuario: admin / contrasena: admin123)."
  value       = "http://${aws_instance.app_server.public_ip}:3000"
}

output "prometheus_url" {
  description = "URL de Prometheus."
  value       = "http://${aws_instance.app_server.public_ip}:9090"
}

output "nota" {
  description = "Aviso importante."
  value       = "Espera 2-3 minutos despues del apply para que Docker termine de levantar los contenedores."
}
