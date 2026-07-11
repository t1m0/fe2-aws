locals {
  fe2_count = 1
}
## EFS Access Points

module "access_point_app_logs" {
  count          = local.fe2_count
  source         = "./modules/efs_access_point"
  file_system_id = aws_efs_file_system.main[0].id
  path           = "/app/logs"
  tags           = local.common_tags
}

module "access_point_app_config" {
  count          = local.fe2_count
  source         = "./modules/efs_access_point"
  file_system_id = aws_efs_file_system.main[0].id
  path           = "/app/config"
  tags           = local.common_tags
}

module "access_point_app_cacerts" {
  count          = local.fe2_count
  source         = "./modules/efs_access_point"
  file_system_id = aws_efs_file_system.main[0].id
  path           = "/app/cacerts"
  tags           = local.common_tags
}

## ECS Service

module "fe2" {
  count                   = local.fe2_count
  depends_on              = [module.mongodb]
  source                  = "./modules/ecs-service"
  aws_region              = var.aws_region
  name                    = "fe2"
  image                   = "${aws_ecr_repository.main.repository_url}:2.40-new"
  cpu                     = 512
  memory                  = 2048
  task_execution_role_arn = aws_iam_role.ecs-task-execution-role.arn
  ecs_cluster_id          = aws_ecs_cluster.main.id
  enable_execute_command  = true
  ports = [
    {
      port    = local.fe2_port
      alb_arn = aws_lb_target_group.http.arn
    }
  ]
  subnets                           = aws_subnet.private[*].id
  security_groups                   = [aws_security_group.app.id]
  health_check_grace_period_seconds = 240
  environment = [
    {
      name  = "FE2_EMAIL",
      value = var.fe2_registry_email
    },
    {
      name  = "FE2_PASSWORD",
      value = var.fe2_registry_password
    },
    {
      name  = "FE2_ACTIVATION_NAME",
      value = "fe2_aws"
    },
    {
      name  = "FE2_LOG_LEVEL",
      value = "debug"
    },
    {
      name  = "CERTBOT_ENABLED",
      value = "true"
    },
    {
      name  = "CERTBOT_DOMAIN",
      value = "alamos.fw-binzen.de"
    },
    {
      name  = "CERTBOT_EMAIL",
      value = "certbot@feuerwehr-binzen.de"
    },
    {
      name  = "FE2_IP_MONGODB",
      value = "mongodb.${local.project_name}.local"
    },
    {
      name  = "FE2_PORT_MONGODB",
      value = tostring(local.mongodb_port)
    }
  ]
  mountPoints = [
    {
      sourceVolume  = "app-config-vol"
      containerPath = "/Config" # From docker-compose
      readOnly      = false
    },
    {
      sourceVolume  = "app-logs-vol"
      containerPath = "/Logs" # From docker-compose
      readOnly      = false
    },
    {
      sourceVolume = "app-cacerts-vol"
      #containerPath = "/usr/lib/jvm/default-jvm/jre/lib/security/cacerts" # From docker-compose
      containerPath = "/etc/ssl/certs/custom"
      readOnly      = true # Typically, cacerts are read-only
    }
  ]
  file_system_id = aws_efs_file_system.main[0].id
  volumes = [
    {
      name            = "app-config-vol"
      access_point_id = module.access_point_app_config[0].id
    },
    {
      name            = "app-logs-vol"
      access_point_id = module.access_point_app_logs[0].id
    },
    {
      name            = "app-cacerts-vol"
      access_point_id = module.access_point_app_cacerts[0].id
    }
  ]
  tags = local.common_tags
}

# Security Group Rules
resource "aws_security_group_rule" "app_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound traffic from App"
}

resource "aws_security_group_rule" "app_ingress_from_alb" {
  type                     = "ingress"
  from_port                = local.fe2_port
  to_port                  = local.fe2_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id # Allow traffic from ALB
  description              = "Allow HTTP traffic from ALB"
}
