resource "aws_secretsmanager_secret" "fe2_credentials" {
  name        = "fe2-app/fe2_credentials"
  description = "FE2 container registry credentials (email + password)"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "fe2_credentials" {
  secret_id = aws_secretsmanager_secret.fe2_credentials.id

  secret_string = jsonencode({
    email    = var.fe2_registry_email
    password = var.fe2_registry_password
  })

  lifecycle {
    ignore_changes = [secret_string, secret_string_wo_version, version_stages]
  }
}
