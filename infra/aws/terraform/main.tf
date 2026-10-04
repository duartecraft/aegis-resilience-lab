data "aws_caller_identity" "current" {}

locals {
  name = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    ManagedBy   = "terraform"
    Environment = var.environment
    Owner       = var.owner
  }

  app_log_group_name = "/ecs/${local.name}/app"
  container_port     = 8000

  # Sem NAT Gateway, as tasks ficam em subnets públicas com IP público.
  # O security group continua aceitando tráfego apenas do load balancer.
  tasks_in_public_subnets = var.nat_gateway_mode == "none"
}

module "network" {
  source = "./modules/network"

  name             = local.name
  vpc_cidr         = var.vpc_cidr
  az_count         = var.az_count
  nat_gateway_mode = var.nat_gateway_mode
  container_port   = local.container_port
}

module "ecr" {
  source = "./modules/ecr"

  name         = "${local.name}/app"
  force_delete = var.force_destroy
}

module "notifications" {
  source = "./modules/notifications"

  name             = local.name
  alert_email      = var.alert_email
  enable_budget    = var.enable_budget
  budget_limit_usd = var.budget_limit_usd
}

module "rds" {
  source = "./modules/rds"
  count  = var.enable_database ? 1 : 0

  name                  = local.name
  subnet_ids            = module.network.data_subnet_ids
  security_group_id     = module.network.db_security_group_id
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  skip_final_snapshot   = var.force_destroy
}

module "iam" {
  source = "./modules/iam"

  name               = local.name
  account_id         = data.aws_caller_identity.current.account_id
  ecr_repository_arn = module.ecr.repository_arn
  log_group_arn      = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${local.app_log_group_name}"
  app_secret_arn     = aws_secretsmanager_secret.app.arn
  enable_migration   = var.enable_database
  master_secret_arn  = var.enable_database ? module.rds[0].master_secret_arn : null
}

module "alb" {
  source = "./modules/alb"
  count  = var.enable_load_balancer ? 1 : 0

  name                = local.name
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids
  security_group_id   = module.network.alb_security_group_id
  container_port      = local.container_port
  certificate_arn     = var.certificate_arn
  domain_name         = var.domain_name
  deletion_protection = var.alb_deletion_protection
}

module "ecs" {
  source = "./modules/ecs"

  name               = local.name
  region             = var.aws_region
  log_group_name     = local.app_log_group_name
  log_retention_days = var.log_retention_days
  container_insights = var.container_insights

  repository_url   = module.ecr.repository_url
  image_tag        = var.image_tag
  app_version      = var.app_version
  cpu_architecture = var.cpu_architecture
  task_cpu         = var.task_cpu
  task_memory      = var.task_memory
  container_port   = local.container_port

  enable_tasks = var.enable_database
  db_host      = var.enable_database ? module.rds[0].address : null
  db_port      = var.enable_database ? module.rds[0].port : null
  db_name      = var.enable_database ? module.rds[0].db_name : null

  app_secret_arn    = aws_secretsmanager_secret.app.arn
  master_secret_arn = var.enable_database ? module.rds[0].master_secret_arn : null

  app_execution_role_arn     = module.iam.app_execution_role_arn
  migrate_execution_role_arn = module.iam.migrate_execution_role_arn
  task_role_arn              = module.iam.task_role_arn

  enable_service        = var.enable_service
  desired_count         = var.desired_count
  subnet_ids            = local.tasks_in_public_subnets ? module.network.public_subnet_ids : module.network.app_subnet_ids
  assign_public_ip      = local.tasks_in_public_subnets
  security_group_id     = module.network.app_security_group_id
  target_group_arn      = var.enable_load_balancer ? module.alb[0].target_group_arn : null
  wait_for_steady_state = true

  # As credenciais precisam existir antes de as tasks iniciarem.
  depends_on = [aws_secretsmanager_secret_version.app]
}

module "observability" {
  source = "./modules/observability"

  name          = local.name
  region        = var.aws_region
  account_id    = data.aws_caller_identity.current.account_id
  sns_topic_arn = module.notifications.topic_arn
  force_destroy = var.force_destroy

  enable_alarms     = var.enable_alarms
  enable_cloudtrail = var.enable_cloudtrail

  enable_alb_alarms        = var.enable_alarms && var.enable_service
  alb_arn_suffix           = var.enable_load_balancer ? module.alb[0].arn_suffix : null
  target_group_arn_suffix  = var.enable_load_balancer ? module.alb[0].target_group_arn_suffix : null
  ecs_cluster_name         = module.ecs.cluster_name
  ecs_service_name         = module.ecs.service_name
  desired_count            = var.desired_count
  enable_db_alarms         = var.enable_alarms && var.enable_database
  db_instance_identifier   = var.enable_database ? module.rds[0].identifier : null
  db_allocated_storage     = var.db_allocated_storage
  db_max_connections_alarm = var.db_max_connections_alarm
  app_log_group_name       = local.app_log_group_name
}
