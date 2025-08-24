resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${local.project_name}.local" # This will resolve to fe2-app.local
  description = "Private DNS namespace for ${local.project_name} services"
  vpc         = aws_vpc.main.id
}

resource "aws_ecs_cluster" "main" {
  name = "${local.project_name}-cluster"
}

resource "aws_ecr_repository" "main" {
  name                 = "${local.project_name}-ecr"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}
