# Credenciais de execução da aplicação.
#
# Os valores são gerados como recursos efêmeros e gravados com um atributo
# write-only: não ficam no state nem no plano. Para gerar novas credenciais,
# incremente app_secret_version e execute a task de migração, que aplica a
# nova senha ao usuário do banco.
ephemeral "random_password" "app_db" {
  length  = 32
  special = false
}

ephemeral "random_password" "events_token" {
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.name}/app-runtime"
  description             = "Usuario de banco da aplicacao (sem DDL) e token de POST /api/events."
  recovery_window_in_days = var.force_destroy ? 0 : 30
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string_wo = jsonencode({
    username         = "aegis_app"
    password         = ephemeral.random_password.app_db.result
    events_api_token = ephemeral.random_password.events_token.result
  })
  secret_string_wo_version = var.app_secret_version
}
