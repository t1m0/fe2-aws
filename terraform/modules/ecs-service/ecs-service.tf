resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
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
      }
    ]
  })
}

resource "aws_ecs_task_definition" "ecs" {
  family                   = "${var.name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = aws_iam_role.ecs.arn
  container_definitions = jsonencode([
    {
      name      = "${var.name}-container"
      image     = var.image
      cpu       = var.cpu
      memory    = var.memory
      essential = true
      portMappings = [
        {
          containerPort = var.port
          hostPort      = var.port
          protocol      = "tcp"
        }
      ]
      environment = var.environment
      mountPoints = var.mountPoints

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  dynamic "volume" {
    for_each = var.volumes
    content {
      name = volume.value.name
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
  name            = "${var.name}-service"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.ecs.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  # Force new deployment when task definition changes
  force_new_deployment = true

  # Ensure service is recreated when task definition changes
  triggers = {
    redeployment = plantimestamp()
  }

  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_groups
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.alb_arn != null ? [1] : []
    content {
      target_group_arn = var.alb_arn
      container_name   = "${var.name}-container"
      container_port   = var.port
    }
  }

  dynamic "service_registries" {
    for_each = var.service_registry_arn != null ? [1] : []
    content {
      registry_arn = var.service_registry_arn
    }
  }

}
