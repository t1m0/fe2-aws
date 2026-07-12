resource "aws_efs_file_system" "main" {
  count            = 1
  creation_token   = "${local.project_name}-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"
  encrypted        = true

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_efs_mount_target" "main" {
  count           = var.az_count
  file_system_id  = aws_efs_file_system.main[0].id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# Security Group Rules
resource "aws_security_group_rule" "efs_ingress_from_app" {
  type                     = "ingress"
  from_port                = 2049 # NFS port
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  description              = "Allow NFS from app"
  source_security_group_id = aws_security_group.app.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "efs_ingress_from_db" {
  type                     = "ingress"
  from_port                = 2049 # NFS port
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  description              = "Allow NFS from DB"
  source_security_group_id = aws_security_group.db.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_backup_vault" "main" {
  name = "${local.project_name}-backup-vault"
  tags = local.common_tags
}

resource "aws_backup_plan" "daily" {
  name = "${local.project_name}-daily-backup"
  tags = local.common_tags

  rule {
    rule_name         = "daily-tue-sun"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 ? * TUE-SUN *)"

    lifecycle {
      delete_after = 7
    }
  }

  rule {
    rule_name         = "weekly-monday"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 ? * MON *)"

    lifecycle {
      delete_after = 30
    }
  }
}

resource "aws_iam_role" "backup" {
  name = "${local.project_name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      },
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup.name
}

resource "aws_backup_selection" "efs" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${local.project_name}-efs-backup-selection"
  plan_id      = aws_backup_plan.daily.id

  resources = [
    aws_efs_file_system.main[0].arn
  ]
}
