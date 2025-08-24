locals {
  mongodb_count = 1
}

resource "aws_service_discovery_service" "mongodb" {
  count = local.mongodb_count
  name  = "mongodb" # This will be the service name within the namespace

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.main.id
    routing_policy = "MULTIVALUE" # Allows multiple IP addresses for the same DNS name
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

module "access_point_db_data" {
  count          = local.mongodb_count
  source         = "./modules/efs_access_point"
  file_system_id = aws_efs_file_system.main[0].id
  path           = "/data/db"
  group_id       = 999
  user_id        = 999
  permissions    = "0700"
}

module "mongodb" {
  count      = local.mongodb_count
  source     = "./modules/ecs-service"
  aws_region = var.aws_region
  name       = "mongodb"
  image      = "mongo:5.0.29"
  memory     = 2048

  task_execution_role_arn = aws_iam_role.ecs-task-execution-role.arn
  ecs_cluster_id          = aws_ecs_cluster.main.id
  service_registry_arn    = aws_service_discovery_service.mongodb[0].arn
  subnets                 = aws_subnet.private[*].id
  security_groups         = [aws_security_group.db.id]
  port                    = local.mongodb_port
  mountPoints = [
    {
      sourceVolume  = "db-data-vol"
      containerPath = "/data/db"
      readOnly      = false
    }
  ]
  file_system_id = aws_efs_file_system.main[0].id
  volumes = [
    {
      name            = "db-data-vol"
      access_point_id = module.access_point_db_data[0].id
    }
  ]
}

# Security Group Rules
resource "aws_security_group_rule" "db_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"] # For pulling images, etc.
  security_group_id = aws_security_group.db.id
  description       = "Allow all outbound traffic from DB"
}

resource "aws_security_group_rule" "db_ingress_from_app" {
  type                     = "ingress"
  from_port                = local.mongodb_port
  to_port                  = local.mongodb_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.app.id # Allow traffic from App SG
  description              = "Allow DB traffic from App SG"
}
