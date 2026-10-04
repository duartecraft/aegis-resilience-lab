variable "name" {
  type = string
}

variable "account_id" {
  type = string
}

variable "ecr_repository_arn" {
  type = string
}

variable "log_group_arn" {
  type = string
}

variable "app_secret_arn" {
  type = string
}

variable "enable_migration" {
  type = bool
}

variable "master_secret_arn" {
  type    = string
  default = null
}

data "aws_iam_policy_document" "assume_ecs_tasks" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

# Permissões comuns a qualquer execução: baixar a imagem deste repositório e
# gravar no log group da aplicação. Nada além disso.
data "aws_iam_policy_document" "pull_and_log" {
  statement {
    sid       = "EcrAuthorization"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid = "WriteLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${var.log_group_arn}:*"]
  }
}

# --- Execução da aplicação: lê apenas o segredo da aplicação ---
data "aws_iam_policy_document" "app_secrets" {
  statement {
    sid       = "ReadAppSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.app_secret_arn]
  }
}

resource "aws_iam_role" "app_execution" {
  name               = "${var.name}-app-execution"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
}

resource "aws_iam_role_policy" "app_execution_base" {
  name   = "pull-and-log"
  role   = aws_iam_role.app_execution.id
  policy = data.aws_iam_policy_document.pull_and_log.json
}

resource "aws_iam_role_policy" "app_execution_secrets" {
  name   = "read-app-secret"
  role   = aws_iam_role.app_execution.id
  policy = data.aws_iam_policy_document.app_secrets.json
}

# --- Execução da migração: única identidade que lê a senha mestre do banco ---
data "aws_iam_policy_document" "migrate_secrets" {
  count = var.enable_migration ? 1 : 0

  statement {
    sid       = "ReadAppAndMasterSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.app_secret_arn, var.master_secret_arn]
  }
}

resource "aws_iam_role" "migrate_execution" {
  count = var.enable_migration ? 1 : 0

  name               = "${var.name}-migrate-execution"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
}

resource "aws_iam_role_policy" "migrate_execution_base" {
  count = var.enable_migration ? 1 : 0

  name   = "pull-and-log"
  role   = aws_iam_role.migrate_execution[0].id
  policy = data.aws_iam_policy_document.pull_and_log.json
}

resource "aws_iam_role_policy" "migrate_execution_secrets" {
  count = var.enable_migration ? 1 : 0

  name   = "read-app-and-master-secrets"
  role   = aws_iam_role.migrate_execution[0].id
  policy = data.aws_iam_policy_document.migrate_secrets[0].json
}

# --- Papel da task: a aplicação não chama APIs da AWS, então não há políticas ---
resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_tasks.json
}

output "app_execution_role_arn" {
  value = aws_iam_role.app_execution.arn
}

output "migrate_execution_role_arn" {
  value = var.enable_migration ? aws_iam_role.migrate_execution[0].arn : null
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}
