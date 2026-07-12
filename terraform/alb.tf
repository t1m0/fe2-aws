resource "aws_lb" "app" {
  name               = "${local.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = local.alb_enable_deletion_protection

  dynamic "access_logs" {
    for_each = local.alb_access_logs_enabled && var.alb_access_logs_bucket != null ? [1] : []

    content {
      bucket  = var.alb_access_logs_bucket
      prefix  = coalesce(var.alb_access_logs_prefix, "")
      enabled = true
    }
  }

  tags = local.common_tags
}

check "alb_access_logs_bucket_present" {
  assert {
    condition     = !local.alb_access_logs_enabled || var.alb_access_logs_bucket != null
    error_message = "Set alb_access_logs_bucket when enabling ALB access logs."
  }
}

resource "aws_lb_target_group" "http" {
  name        = "${local.project_name}-http-tg"
  port        = local.fe2_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Required for Fargate

  health_check {
    enabled             = true
    path                = "/" # From fe2_app healthcheck: http://localhost:83/
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 10
    matcher             = "200-499"
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      stickiness,
      target_failover,
      target_group_health,
      target_health_state
    ]
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = local.common_tags
}

resource "aws_lb_listener_rule" "http_redirect_all" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.app.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }

  tags = local.common_tags
}
