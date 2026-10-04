locals {
  alb_metric_dims = ["LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix]
  ecs_metric_dims = ["ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]

  alb_widgets = [for widget in [
    {
      type = "metric", x = 0, y = 0, width = 12, height = 6
      properties = {
        title  = "Trafego e erros"
        region = var.region
        stat   = "Sum"
        period = 60
        metrics = [
          concat(["AWS/ApplicationELB", "RequestCount"], local.alb_metric_dims),
          concat(["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count"], local.alb_metric_dims),
          ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix],
        ]
      }
    },
    {
      type = "metric", x = 12, y = 0, width = 12, height = 6
      properties = {
        title  = "Latencia (p50, p95, p99)"
        region = var.region
        period = 60
        metrics = [
          concat(["AWS/ApplicationELB", "TargetResponseTime"], local.alb_metric_dims, [{ stat = "p50" }]),
          concat(["AWS/ApplicationELB", "TargetResponseTime"], local.alb_metric_dims, [{ stat = "p95" }]),
          concat(["AWS/ApplicationELB", "TargetResponseTime"], local.alb_metric_dims, [{ stat = "p99" }]),
        ]
      }
    },
    {
      type = "metric", x = 0, y = 6, width = 12, height = 6
      properties = {
        title  = "Targets saudaveis e nao saudaveis"
        region = var.region
        stat   = "Maximum"
        period = 60
        metrics = [
          concat(["AWS/ApplicationELB", "HealthyHostCount"], local.alb_metric_dims),
          concat(["AWS/ApplicationELB", "UnHealthyHostCount"], local.alb_metric_dims),
        ]
      }
    },
    {
      type = "metric", x = 12, y = 6, width = 12, height = 6
      properties = {
        title  = "ECS: CPU e memoria do servico (%)"
        region = var.region
        stat   = "Average"
        period = 60
        metrics = [
          concat(["AWS/ECS", "CPUUtilization"], local.ecs_metric_dims),
          concat(["AWS/ECS", "MemoryUtilization"], local.ecs_metric_dims),
        ]
      }
    },
  ] : widget if var.enable_alb_alarms]

  db_widgets = [for widget in [
    {
      type = "metric", x = 0, y = 12, width = 12, height = 6
      properties = {
        title  = "RDS: CPU (%) e conexoes"
        region = var.region
        stat   = "Average"
        period = 60
        metrics = [
          ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_identifier],
          ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_instance_identifier, { yAxis = "right" }],
        ]
      }
    },
    {
      type = "metric", x = 12, y = 12, width = 12, height = 6
      properties = {
        title  = "RDS: armazenamento e memoria livres (bytes)"
        region = var.region
        stat   = "Minimum"
        period = 300
        metrics = [
          ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.db_instance_identifier],
          ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", var.db_instance_identifier, { yAxis = "right" }],
        ]
      }
    },
  ] : widget if var.enable_db_alarms]
}

resource "aws_cloudwatch_dashboard" "this" {
  count = var.enable_alarms ? 1 : 0

  dashboard_name = var.name
  dashboard_body = jsonencode({
    widgets = concat(local.alb_widgets, local.db_widgets)
  })
}

output "dashboard_name" {
  value = var.enable_alarms ? aws_cloudwatch_dashboard.this[0].dashboard_name : null
}
