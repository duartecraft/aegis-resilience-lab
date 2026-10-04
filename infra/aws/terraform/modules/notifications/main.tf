variable "name" {
  type = string
}

variable "alert_email" {
  type    = string
  default = null
}

variable "enable_budget" {
  type = bool
}

variable "budget_limit_usd" {
  type = number
}

data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
}

# Além da conta, permite a publicação pelos serviços que geram os alertas.
data "aws_iam_policy_document" "alerts" {
  statement {
    sid       = "AllowAlertingServices"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type = "Service"
      identifiers = [
        "cloudwatch.amazonaws.com",
        "events.amazonaws.com",
        "events.rds.amazonaws.com",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}

# A assinatura por e-mail só passa a valer depois de confirmada pelo destinatário.
resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Orçamento mensal medido pelo uso bruto: créditos e reembolsos não escondem o gasto.
resource "aws_budgets_budget" "monthly" {
  count = var.enable_budget && var.alert_email != null ? 1 : 0

  name         = "${var.name}-monthly"
  budget_type  = "COST"
  time_unit    = "MONTHLY"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"

  cost_types {
    include_credit = false
    include_refund = false
  }

  dynamic "notification" {
    for_each = [50, 80, 100]

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.alert_email]
    }
  }
}

output "topic_arn" {
  value = aws_sns_topic.alerts.arn
}
