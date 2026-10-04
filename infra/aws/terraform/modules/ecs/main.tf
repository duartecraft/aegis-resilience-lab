locals {
  image = "${var.repository_url}:${var.image_tag}"

  # Conexão com TLS validado contra a cadeia do banco gerenciado, incluída na imagem.
  database_environment = [
    { name = "DB_HOST", value = var.db_host },
    { name = "DB_PORT", value = tostring(var.db_port) },
    { name = "DB_NAME", value = var.db_name },
    { name = "DB_SSLMODE", value = "verify-full" },
    { name = "DB_SSLROOTCERT", value = "/etc/ssl/certs/rds-global-bundle.pem" },
  ]

  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = aws_cloudwatch_log_group.app.name
      "awslogs-region"        = var.region
      "awslogs-stream-prefix" = "ecs"
    }
  }

  health_check_command = "import sys, urllib.request; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:${var.container_port}/health', timeout=2).status == 200 else 1)"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = var.container_insights
  }
}

# --- Aplicação ---
resource "aws_ecs_task_definition" "app" {
  count = var.enable_tasks ? 1 : 0

  family                   = "${var.name}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.app_execution_role_arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  # O sistema de arquivos do container é somente leitura; /tmp é um volume efêmero.
  volume {
    name = "tmp"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = local.image
      essential = true

      portMappings = [
        { containerPort = var.container_port, protocol = "tcp" }
      ]

      environment = concat(local.database_environment, [
        { name = "APP_VERSION", value = var.app_version },
      ])

      # O usuário de banco da aplicação não tem permissão de DDL.
      secrets = [
        { name = "DB_USER", valueFrom = "${var.app_secret_arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${var.app_secret_arn}:password::" },
        { name = "EVENTS_API_TOKEN", valueFrom = "${var.app_secret_arn}:events_api_token::" },
      ]

      readonlyRootFilesystem = true
      mountPoints = [
        { sourceVolume = "tmp", containerPath = "/tmp", readOnly = false }
      ]

      stopTimeout = 30

      healthCheck = {
        command     = ["CMD", "python", "-c", local.health_check_command]
        interval    = 15
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }

      logConfiguration = local.log_configuration
    }
  ])
}

# --- Migração de schema: execução única, com a senha mestre ---
resource "aws_ecs_task_definition" "migrate" {
  count = var.enable_tasks ? 1 : 0

  family                   = "${var.name}-migrate"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.migrate_execution_role_arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([
    {
      name      = "migrate"
      image     = local.image
      essential = true
      command   = ["python", "-m", "app.migrate"]

      environment = local.database_environment

      secrets = [
        { name = "DB_USER", valueFrom = "${var.master_secret_arn}:username::" },
        { name = "DB_PASSWORD", valueFrom = "${var.master_secret_arn}:password::" },
        { name = "APP_DB_USER", valueFrom = "${var.app_secret_arn}:username::" },
        { name = "APP_DB_PASSWORD", valueFrom = "${var.app_secret_arn}:password::" },
      ]

      readonlyRootFilesystem = true
      logConfiguration       = local.log_configuration
    }
  ])
}

resource "aws_ecs_service" "app" {
  count = var.enable_service ? 1 : 0

  name            = "${var.name}-app"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app[0].arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Deploy rolling sem perda de capacidade, com reversão automática se as
  # novas tasks não ficarem saudáveis.
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = 30
  enable_execute_command            = false
  propagate_tags                    = "SERVICE"
  wait_for_steady_state             = var.wait_for_steady_state

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = var.container_port
  }
}
