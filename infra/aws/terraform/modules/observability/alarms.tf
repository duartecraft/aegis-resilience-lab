# Cada alarme notifica o tópico SNS ao disparar e ao normalizar, e aponta
# para um runbook em docs/09-runbooks.md.
locals {
  alb_dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  ecs_dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  db_dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }

  alb_alarms = {
    target-unhealthy = {
      description = "Ao menos um target nao saudavel. Runbook: target unhealthy."
      namespace   = "AWS/ApplicationELB"
      metric      = "UnHealthyHostCount"
      dimensions  = local.alb_dimensions
      statistic   = "Maximum"
      period      = 60
      evaluations = 2
      comparison  = "GreaterThanOrEqualToThreshold"
      threshold   = 1
      missing     = "notBreaching"
    }
    capacity-reduced = {
      description = "Menos targets saudaveis que o desejado. Runbook: target unhealthy."
      namespace   = "AWS/ApplicationELB"
      metric      = "HealthyHostCount"
      dimensions  = local.alb_dimensions
      statistic   = "Minimum"
      period      = 60
      evaluations = 2
      comparison  = "LessThanThreshold"
      threshold   = var.desired_count
      missing     = "breaching"
    }
    elb-5xx = {
      description = "Erros 5xx gerados pelo load balancer. Runbook: 5xx elevado."
      namespace   = "AWS/ApplicationELB"
      metric      = "HTTPCode_ELB_5XX_Count"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
      statistic   = "Sum"
      period      = 300
      evaluations = 1
      comparison  = "GreaterThanOrEqualToThreshold"
      threshold   = 5
      missing     = "notBreaching"
    }
    ecs-cpu-high = {
      description = "CPU do servico acima de 80%. Runbook: alta latencia."
      namespace   = "AWS/ECS"
      metric      = "CPUUtilization"
      dimensions  = local.ecs_dimensions
      statistic   = "Average"
      period      = 300
      evaluations = 2
      comparison  = "GreaterThanThreshold"
      threshold   = 80
      missing     = "notBreaching"
    }
    ecs-memory-high = {
      description = "Memoria do servico acima de 80%. Runbook: alta latencia."
      namespace   = "AWS/ECS"
      metric      = "MemoryUtilization"
      dimensions  = local.ecs_dimensions
      statistic   = "Average"
      period      = 300
      evaluations = 2
      comparison  = "GreaterThanThreshold"
      threshold   = 80
      missing     = "notBreaching"
    }
  }

  db_alarms = {
    rds-cpu-high = {
      description = "CPU do banco acima de 80%. Runbook: indisponibilidade do RDS."
      namespace   = "AWS/RDS"
      metric      = "CPUUtilization"
      dimensions  = local.db_dimensions
      statistic   = "Average"
      period      = 300
      evaluations = 2
      comparison  = "GreaterThanThreshold"
      threshold   = 80
      missing     = "notBreaching"
    }
    rds-storage-low = {
      description = "Menos de 20% de espaco livre no banco. Runbook: indisponibilidade do RDS."
      namespace   = "AWS/RDS"
      metric      = "FreeStorageSpace"
      dimensions  = local.db_dimensions
      statistic   = "Minimum"
      period      = 300
      evaluations = 1
      comparison  = "LessThanThreshold"
      threshold   = var.db_allocated_storage * 1024 * 1024 * 1024 * 0.2
      missing     = "notBreaching"
    }
    rds-connections-high = {
      description = "Conexoes do banco acima do limiar. Runbook: indisponibilidade do RDS."
      namespace   = "AWS/RDS"
      metric      = "DatabaseConnections"
      dimensions  = local.db_dimensions
      statistic   = "Maximum"
      period      = 300
      evaluations = 1
      comparison  = "GreaterThanThreshold"
      threshold   = var.db_max_connections_alarm
      missing     = "notBreaching"
    }
    rds-memory-low = {
      description = "Menos de 100 MB de memoria livre no banco. Runbook: indisponibilidade do RDS."
      namespace   = "AWS/RDS"
      metric      = "FreeableMemory"
      dimensions  = local.db_dimensions
      statistic   = "Minimum"
      period      = 300
      evaluations = 2
      comparison  = "LessThanThreshold"
      threshold   = 100 * 1024 * 1024
      missing     = "notBreaching"
    }
  }

  simple_alarms = merge(
    { for key, alarm in local.alb_alarms : key => alarm if var.enable_alb_alarms },
    { for key, alarm in local.db_alarms : key => alarm if var.enable_db_alarms },
  )
}

resource "aws_cloudwatch_metric_alarm" "simple" {
  for_each = local.simple_alarms

  alarm_name          = "${var.name}-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  dimensions          = each.value.dimensions
  statistic           = each.value.statistic
  period              = each.value.period
  evaluation_periods  = each.value.evaluations
  comparison_operator = each.value.comparison
  threshold           = each.value.threshold
  treat_missing_data  = each.value.missing

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
}

# Taxa de erro da aplicação: 5xx dos targets sobre o total de requisições.
resource "aws_cloudwatch_metric_alarm" "target_5xx_rate" {
  count = var.enable_alb_alarms ? 1 : 0

  alarm_name          = "${var.name}-target-5xx-rate"
  alarm_description   = "Mais de 1% das requisicoes com erro 5xx da aplicacao. Runbook: 5xx elevado."
  comparison_operator = "GreaterThanThreshold"
  threshold           = 1
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "rate"
    expression  = "IF(requests > 0, 100 * errors / requests, 0)"
    label       = "Taxa de 5xx (%)"
    return_data = true
  }

  metric_query {
    id = "errors"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      dimensions  = local.alb_dimensions
      stat        = "Sum"
      period      = 60
    }
  }

  metric_query {
    id = "requests"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      dimensions  = local.alb_dimensions
      stat        = "Sum"
      period      = 60
    }
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "latency_p95" {
  count = var.enable_alb_alarms ? 1 : 0

  alarm_name          = "${var.name}-latency-p95"
  alarm_description   = "p95 do tempo de resposta acima de 1 s. Runbook: alta latencia."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = local.alb_dimensions
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
}

# --- Eventos: failover e falhas do banco; deploy revertido no ECS ---
resource "aws_db_event_subscription" "db" {
  count = var.enable_db_alarms ? 1 : 0

  name        = "${var.name}-db-events"
  sns_topic   = var.sns_topic_arn
  source_type = "db-instance"
  source_ids  = [var.db_instance_identifier]

  event_categories = [
    "availability",
    "failover",
    "failure",
    "low storage",
    "recovery",
  ]
}

resource "aws_cloudwatch_event_rule" "ecs_deployment_failed" {
  count = var.enable_alb_alarms ? 1 : 0

  name        = "${var.name}-ecs-deployment-failed"
  description = "Deploy do servico ECS falhou e foi revertido. Runbook: rollback de deploy."

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Deployment State Change"]
    detail = {
      eventName = ["SERVICE_DEPLOYMENT_FAILED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "ecs_deployment_failed" {
  count = var.enable_alb_alarms ? 1 : 0

  rule = aws_cloudwatch_event_rule.ecs_deployment_failed[0].name
  arn  = var.sns_topic_arn
}
