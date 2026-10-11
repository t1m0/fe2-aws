# Scheduled logical backup of MongoDB.
# AWS Backup copies the live WiredTiger files on EFS, which is not guaranteed to
# be consistent across files. This task writes a mongodump archive to EFS ahead
# of the AWS Backup window so every recovery point contains a restorable dump.

locals {
  mongodb_backup_name           = "mongodb-backup"
  mongodb_backup_retention_days = 7

  mongodb_backup_script = <<-EOT
    set -euo pipefail
    target="/backup/fe2-$(date -u +%Y%m%dT%H%M%SZ).archive.gz"
    mongodump --host "$MONGODB_HOST" --port "$MONGODB_PORT" --gzip --archive="$target.partial"
    mv "$target.partial" "$target"
    find /backup -name '*.archive.gz' -mtime +"$RETENTION_DAYS" -delete
    find /backup -name '*.partial' -mtime +1 -delete
    ls -l /backup
  EOT
}

module "access_point_db_backup" {
  source         = "./modules/efs_access_point"
  file_system_id = aws_efs_file_system.main[0].id
  path           = "/backup/mongodb"
  group_id       = 999
  user_id        = 999
  permissions    = "0700"
  tags           = local.common_tags
}

resource "aws_cloudwatch_log_group" "mongodb_backup" {
  name              = "/ecs/${local.mongodb_backup_name}"
  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_iam_role" "mongodb_backup_task" {
  name = "${local.mongodb_backup_name}-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "mongodb_backup_task" {
  name = "${local.mongodb_backup_name}-task-policy"
  role = aws_iam_role.mongodb_backup_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ]
        Resource = aws_efs_file_system.main[0].arn
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn" = module.access_point_db_backup.arn
          }
        }
      }
    ]
  })
}

resource "aws_ecs_task_definition" "mongodb_backup" {
  family                   = "${local.mongodb_backup_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs-task-execution-role.arn
  task_role_arn            = aws_iam_role.mongodb_backup_task.arn
  tags                     = local.common_tags

  container_definitions = jsonencode([
    {
      name      = "${local.mongodb_backup_name}-container"
      image     = "${aws_ecr_repository.mongo.repository_url}:8.0"
      essential = true
      command   = ["bash", "-c", local.mongodb_backup_script]
      environment = [
        {
          name  = "MONGODB_HOST"
          value = "mongodb.${local.project_name}.local"
        },
        {
          name  = "MONGODB_PORT"
          value = tostring(local.mongodb_port)
        },
        {
          name  = "RETENTION_DAYS"
          value = tostring(local.mongodb_backup_retention_days)
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "db-backup-vol"
          containerPath = "/backup"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.mongodb_backup.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = local.mongodb_backup_name
        }
      }
    }
  ])

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  volume {
    name = "db-backup-vol"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.main[0].id
      root_directory     = "/"
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = module.access_point_db_backup.id
        iam             = "ENABLED"
      }
    }
  }
}

# Schedule
resource "aws_iam_role" "mongodb_backup_scheduler" {
  name = "${local.mongodb_backup_name}-scheduler-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "mongodb_backup_scheduler" {
  name = "${local.mongodb_backup_name}-scheduler-policy"
  role = aws_iam_role.mongodb_backup_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecs:RunTask"
        Resource = "${aws_ecs_task_definition.mongodb_backup.arn_without_revision}:*"
        Condition = {
          ArnEquals = {
            "ecs:cluster" = aws_ecs_cluster.main.arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.ecs-task-execution-role.arn,
          aws_iam_role.mongodb_backup_task.arn
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Runs two hours before the AWS Backup rules in efs.tf (05:00 UTC).
resource "aws_scheduler_schedule" "mongodb_backup" {
  name                         = "${local.mongodb_backup_name}-daily"
  description                  = "Daily mongodump to EFS ahead of the AWS Backup window"
  schedule_expression          = "cron(0 3 * * ? *)"
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_ecs_cluster.main.arn
    role_arn = aws_iam_role.mongodb_backup_scheduler.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.mongodb_backup.arn
      launch_type         = "FARGATE"

      network_configuration {
        subnets          = aws_subnet.private[*].id
        security_groups  = [aws_security_group.db_backup.id]
        assign_public_ip = false
      }
    }

    retry_policy {
      maximum_retry_attempts       = 2
      maximum_event_age_in_seconds = 3600
    }
  }
}

# Security Group
resource "aws_security_group" "db_backup" {
  name        = "mongodb-backup-sg"
  description = "MongoDB backup task: outbound to MongoDB, EFS and ECR only"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-mongodb-backup-sg"
  })
}

resource "aws_security_group_rule" "db_backup_egress_mongodb" {
  type                     = "egress"
  from_port                = local.mongodb_port
  to_port                  = local.mongodb_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_backup.id
  source_security_group_id = aws_security_group.db.id
  description              = "Allow backup task to reach MongoDB"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "db_backup_egress_nfs" {
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_backup.id
  source_security_group_id = aws_security_group.efs.id
  description              = "Allow backup task to reach EFS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "db_backup_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.db_backup.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow backup task to reach ECR/S3/CloudWatch over HTTPS via NAT"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "db_ingress_from_backup" {
  type                     = "ingress"
  from_port                = local.mongodb_port
  to_port                  = local.mongodb_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.db_backup.id
  description              = "Allow MongoDB ingress from backup task"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "efs_ingress_from_db_backup" {
  type                     = "ingress"
  from_port                = 2049 # NFS port
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  description              = "Allow NFS from MongoDB backup task"
  source_security_group_id = aws_security_group.db_backup.id

  lifecycle {
    create_before_destroy = true
  }
}
