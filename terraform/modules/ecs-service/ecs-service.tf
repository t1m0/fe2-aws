resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_iam_role" "ecs" {
  name = "${var.name}-task-role"
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

  tags = var.tags
}

resource "aws_iam_role_policy" "ecs" {
  name = "${var.name}-task-policy"
  role = aws_iam_role.ecs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRead"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "elasticfilesystem:AccessedViaMountTarget" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

locals {
  container_definition = merge(
    {
      name      = "${var.name}-container"
      image     = var.image
      cpu       = var.cpu
      memory    = var.memory
      essential = true
      portMappings = [
        for p in var.ports : {
          containerPort = p.port
          hostPort      = p.port
          protocol      = "tcp"
        }
      ]
      environment = var.environment
      mountPoints = var.mountPoints
      stopTimeout = var.stop_timeout
      command     = var.command
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.name
        }
      }
    },
    var.health_check != null ? { healthCheck = var.health_check } : {}
  )
}

resource "aws_ecs_task_definition" "ecs" {
  family                   = "${var.name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = aws_iam_role.ecs.arn
  container_definitions    = jsonencode([local.container_definition])
  tags                     = var.tags

  runtime_platform {
    cpu_architecture        = var.cpu_architecture
    operating_system_family = "LINUX"
  }

  lifecycle {
    ignore_changes = [container_definitions]
  }

  dynamic "volume" {
    for_each = var.volumes
    content {
      configure_at_launch = false
      name                = volume.value.name
      efs_volume_configuration {
        file_system_id     = var.file_system_id
        root_directory     = "/"
        transit_encryption = "ENABLED"
        authorization_config {
          access_point_id = volume.value.access_point_id
          iam             = "ENABLED"
        }
      }
    }
  }
}

resource "aws_ecs_service" "ecs" {
  name                               = "${var.name}-service"
  cluster                            = var.ecs_cluster_id
  task_definition                    = aws_ecs_task_definition.ecs.arn
  desired_count                      = 1
  launch_type                        = "FARGATE"
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  availability_zone_rebalancing      = var.availability_zone_rebalancing
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds

  enable_execute_command = var.enable_execute_command

  force_new_deployment = var.force_new_deployment

  triggers = var.force_new_deployment ? {
    redeployment = plantimestamp()
  } : {}

  dynamic "deployment_circuit_breaker" {
    for_each = var.enable_circuit_breaker ? [1] : []
    content {
      enable   = true
      rollback = true
    }
  }

  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_groups
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = [for p in var.ports : p if p.alb_arn != null]
    content {
      target_group_arn = load_balancer.value.alb_arn
      container_name   = "${var.name}-container"
      container_port   = load_balancer.value.port
    }
  }

  dynamic "service_registries" {
    for_each = var.service_registry_arn != null ? [1] : []
    content {
      registry_arn = var.service_registry_arn
    }
  }

  tags = var.tags
}
