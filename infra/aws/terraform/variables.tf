# ---------------------------------------------------------------------------
# Identificação
# ---------------------------------------------------------------------------
variable "project_name" {
  description = "Nome do projeto, usado como prefixo dos recursos."
  type        = string
  default     = "aegis-resilience-lab"
}

variable "environment" {
  description = "Ambiente (dev, prod)."
  type        = string

  validation {
    condition     = length("${var.project_name}-${var.environment}") <= 26
    error_message = "project_name e environment juntos devem ter no máximo 26 caracteres (limite de nomes do load balancer)."
  }
}

variable "owner" {
  description = "Responsável pelo ambiente, usado na tag Owner."
  type        = string
}

variable "aws_region" {
  description = "Região da AWS."
  type        = string
  default     = "us-east-1"
}

# ---------------------------------------------------------------------------
# Interruptores de custo. Tudo o que é cobrado por hora nasce desligado:
# o operador precisa ligar cada item de forma explícita.
# ---------------------------------------------------------------------------
variable "nat_gateway_mode" {
  description = "none: tasks em subnets públicas, sem NAT. single: um NAT Gateway. per_az: um NAT Gateway por zona."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "single", "per_az"], var.nat_gateway_mode)
    error_message = "Use none, single ou per_az."
  }
}

variable "enable_database" {
  description = "Cria a instância RDS for PostgreSQL (cobrada por hora)."
  type        = bool
  default     = false
}

variable "enable_load_balancer" {
  description = "Cria o Application Load Balancer (cobrado por hora)."
  type        = bool
  default     = false
}

variable "enable_service" {
  description = "Cria o serviço ECS com as tasks Fargate (cobradas por hora). Exige banco e load balancer."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_service || (var.enable_database && var.enable_load_balancer)
    error_message = "enable_service exige enable_database e enable_load_balancer."
  }
}

variable "enable_alarms" {
  description = "Cria alarmes, dashboard e regras de evento."
  type        = bool
  default     = false
}

variable "enable_cloudtrail" {
  description = "Cria uma trilha do CloudTrail com bucket próprio."
  type        = bool
  default     = false
}

variable "enable_budget" {
  description = "Cria um orçamento mensal com alertas por e-mail. Exige alert_email."
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Permite destruir o ambiente sem retenção (repositório de imagens, segredos e buckets). Use true apenas em laboratório."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Rede
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "Bloco CIDR da VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Quantidade de zonas de disponibilidade."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "Use 2 ou 3 zonas."
  }
}

# ---------------------------------------------------------------------------
# Entrada
# ---------------------------------------------------------------------------
variable "certificate_arn" {
  description = "ARN de um certificado do ACM. Se nulo, é gerado um certificado autoassinado (apenas laboratório)."
  type        = string
  default     = null
}

variable "domain_name" {
  description = "Nome usado no certificado autoassinado."
  type        = string
  default     = "api.aegis.example.com"
}

variable "alb_deletion_protection" {
  description = "Proteção contra exclusão do load balancer."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Aplicação
# ---------------------------------------------------------------------------
variable "image_tag" {
  description = "Tag da imagem no ECR."
  type        = string
  default     = "1.1.0"
}

variable "app_version" {
  description = "Versão informada pela aplicação em /api/status."
  type        = string
  default     = "1.1.0"
}

variable "cpu_architecture" {
  description = "Arquitetura das tasks: X86_64 ou ARM64."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "Use X86_64 ou ARM64."
  }
}

variable "task_cpu" {
  description = "Unidades de CPU da task (256 = 0,25 vCPU)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memória da task em MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Quantidade de tasks do serviço."
  type        = number
  default     = 2
}

variable "container_insights" {
  description = "Container Insights do cluster: disabled ou enabled."
  type        = string
  default     = "disabled"
}

variable "log_retention_days" {
  description = "Retenção dos logs da aplicação."
  type        = number
  default     = 14
}

variable "app_secret_version" {
  description = "Incrementar para gerar novas credenciais da aplicação. Depois, execute a task de migração."
  type        = number
  default     = 1
}

# ---------------------------------------------------------------------------
# Banco
# ---------------------------------------------------------------------------
variable "db_instance_class" {
  description = "Classe da instância do banco."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Armazenamento do banco em GiB."
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Standby em outra zona, com failover gerenciado."
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Dias de retenção do backup automático."
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Proteção contra exclusão do banco."
  type        = bool
  default     = false
}

variable "db_max_connections_alarm" {
  description = "Limiar do alarme de conexões do banco."
  type        = number
  default     = 60
}

# ---------------------------------------------------------------------------
# Operação
# ---------------------------------------------------------------------------
variable "alert_email" {
  description = "E-mail que recebe alarmes e alertas de orçamento. Se nulo, o tópico fica sem assinante."
  type        = string
  default     = null
}

variable "budget_limit_usd" {
  description = "Limite mensal do orçamento, em dólares."
  type        = number
  default     = 20
}
