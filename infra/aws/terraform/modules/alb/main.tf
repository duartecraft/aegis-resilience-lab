variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "container_port" {
  type = number
}

variable "certificate_arn" {
  type    = string
  default = null
}

variable "domain_name" {
  type = string
}

variable "deletion_protection" {
  type = bool
}

locals {
  self_signed     = var.certificate_arn == null
  certificate_arn = local.self_signed ? aws_acm_certificate.self_signed[0].arn : var.certificate_arn
}

# --- Certificado autoassinado, apenas para laboratório sem domínio próprio. ---
# A chave privada fica no state do Terraform: aceitável para um certificado
# descartável, inaceitável em produção. Com domínio, informe certificate_arn.
resource "tls_private_key" "self_signed" {
  count = local.self_signed ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed" {
  count = local.self_signed ? 1 : 0

  private_key_pem       = tls_private_key.self_signed[0].private_key_pem
  validity_period_hours = 720
  dns_names             = [var.domain_name]

  subject {
    common_name  = var.domain_name
    organization = "Aegis Resilience Lab"
  }

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "self_signed" {
  count = local.self_signed ? 1 : 0

  private_key      = tls_private_key.self_signed[0].private_key_pem
  certificate_body = tls_self_signed_cert.self_signed[0].cert_pem

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.subnet_ids
  security_groups    = [var.security_group_id]

  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection
  idle_timeout               = 60
}

resource "aws_lb_target_group" "app" {
  name        = "${var.name}-app"
  vpc_id      = var.vpc_id
  target_type = "ip"
  protocol    = "HTTP"
  port        = var.container_port

  # Tempo para concluir requisições em andamento antes de remover a task.
  deregistration_delay = 30

  # /health não consulta o banco: uma falha do banco não retira todas as tasks.
  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.certificate_arn

  routing_http_response_strict_transport_security_header_value = "max-age=31536000; includeSubDomains"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

output "dns_name" {
  value = aws_lb.this.dns_name
}

output "arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.app.arn_suffix
}

# O serviço só pode usar o target group depois de o listener existir.
output "target_group_arn" {
  value      = aws_lb_target_group.app.arn
  depends_on = [aws_lb_listener.https]
}
