output "ecr_repository_url" {
  description = "Endereço do repositório de imagens."
  value       = module.ecr.repository_url
}

output "service_url" {
  description = "URL do load balancer. Com certificado autoassinado, use curl -k."
  value       = var.enable_load_balancer ? "https://${module.alb[0].dns_name}" : null
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Nome do serviço ECS."
  value       = module.ecs.service_name
}

output "migrate_task_definition_arn" {
  description = "Task definition da migração de schema (execução única)."
  value       = module.ecs.migrate_task_definition_arn
}

output "task_subnet_ids" {
  description = "Subnets usadas pelas tasks, para a execução da migração."
  value       = local.tasks_in_public_subnets ? module.network.public_subnet_ids : module.network.app_subnet_ids
}

output "task_assign_public_ip" {
  description = "Indica se as tasks recebem IP público."
  value       = local.tasks_in_public_subnets
}

output "task_security_group_id" {
  description = "Security group das tasks."
  value       = module.network.app_security_group_id
}

output "db_instance_identifier" {
  description = "Identificador da instância do banco."
  value       = var.enable_database ? module.rds[0].identifier : null
}

output "db_master_secret_arn" {
  description = "ARN do segredo da senha mestre, gerido pelo RDS."
  value       = var.enable_database ? module.rds[0].master_secret_arn : null
}

output "app_secret_arn" {
  description = "ARN do segredo de execução da aplicação."
  value       = aws_secretsmanager_secret.app.arn
}

output "app_log_group_name" {
  description = "Log group da aplicação."
  value       = local.app_log_group_name
}

output "sns_topic_arn" {
  description = "Tópico de alertas."
  value       = module.notifications.topic_arn
}

output "dashboard_name" {
  description = "Nome do dashboard do CloudWatch."
  value       = module.observability.dashboard_name
}
