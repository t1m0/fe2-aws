resource "aws_lb" "app" {
  name               = "${local.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false # Set to true for production
}

resource "aws_lb_target_group" "app" {
  name        = "fe2-app-tg"
  port        = local.fe2_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Required for Fargate

  health_check {
    enabled             = true
    path                = "/" # From fe2_app healthcheck: http://localhost:83/
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 5
    timeout             = 10
    matcher             = "200-499"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

