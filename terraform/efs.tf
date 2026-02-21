resource "aws_efs_file_system" "main" {
  count            = 1
  creation_token   = "${local.project_name}-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true
}

resource "aws_efs_mount_target" "main" {
  count           = var.az_count
  file_system_id  = aws_efs_file_system.main[0].id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# Security Group Rules
resource "aws_security_group_rule" "efs_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.efs.id
  description       = "Allow all outbound traffic from EFS SG"
}

resource "aws_security_group_rule" "efs_ingress_from_app_and_db" {
  type                     = "ingress"
  from_port                = 2049 # NFS port
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = aws_security_group.app.id
  description              = "Allow EFS traffic from App SG"
}

resource "aws_security_group_rule" "efs_ingress_from_db" {
  type                     = "ingress"
  from_port                = 2049 # NFS port
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = aws_security_group.db.id
  description              = "Allow EFS traffic from DB SG"
}

resource "aws_backup_vault" "main" {
  name = "${local.project_name}-backup-vault"
}

resource "aws_backup_plan" "daily" {
  name = "${local.project_name}-daily-backup"

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
