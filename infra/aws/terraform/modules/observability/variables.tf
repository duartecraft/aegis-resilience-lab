variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "sns_topic_arn" {
  type = string
}

variable "force_destroy" {
  type = bool
}

variable "enable_alarms" {
  type = bool
}

variable "enable_cloudtrail" {
  type = bool
}

variable "enable_alb_alarms" {
  type = bool
}

variable "alb_arn_suffix" {
  type    = string
  default = null
}

variable "target_group_arn_suffix" {
  type    = string
  default = null
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type    = string
  default = null
}

variable "desired_count" {
  type = number
}

variable "enable_db_alarms" {
  type = bool
}

variable "db_instance_identifier" {
  type    = string
  default = null
}

variable "db_allocated_storage" {
  type = number
}

variable "db_max_connections_alarm" {
  type = number
}

variable "app_log_group_name" {
  type = string
}
