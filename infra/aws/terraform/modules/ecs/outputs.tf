output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = var.enable_service ? aws_ecs_service.app[0].name : null
}

output "migrate_task_definition_arn" {
  value = var.enable_tasks ? aws_ecs_task_definition.migrate[0].arn : null
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}
