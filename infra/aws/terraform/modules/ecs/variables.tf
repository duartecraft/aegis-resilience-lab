variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "log_retention_days" {
  type = number
}

variable "container_insights" {
  type = string
}

variable "repository_url" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "app_version" {
  type = string
}

variable "cpu_architecture" {
  type = string
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "container_port" {
  type = number
}

variable "enable_tasks" {
  description = "Cria as task definitions. Exige o banco."
  type        = bool
}

variable "db_host" {
  type    = string
  default = null
}

variable "db_port" {
  type    = number
  default = null
}

variable "db_name" {
  type    = string
  default = null
}

variable "app_secret_arn" {
  type = string
}

variable "master_secret_arn" {
  type    = string
  default = null
}

variable "app_execution_role_arn" {
  type = string
}

variable "migrate_execution_role_arn" {
  type    = string
  default = null
}

variable "task_role_arn" {
  type = string
}

variable "enable_service" {
  type = bool
}

variable "desired_count" {
  type = number
}

variable "subnet_ids" {
  type = list(string)
}

variable "assign_public_ip" {
  type = bool
}

variable "security_group_id" {
  type = string
}

variable "target_group_arn" {
  type    = string
  default = null
}

variable "wait_for_steady_state" {
  type    = bool
  default = true
}
