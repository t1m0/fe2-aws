data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-vpc"
  })
}

resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + var.az_count)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-${count.index + 1}"
    Tier = "private"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count  = var.az_count
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = format("%s-nat-eip-%d", local.project_name, count.index + 1)
  })
}

resource "aws_nat_gateway" "main" {
  count         = var.az_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id # NAT GW must be in a public subnet
  depends_on    = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = format("%s-nat-%d", local.project_name, count.index + 1)
  })
}

resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = format("%s-private-rt-%d", local.project_name, count.index + 1)
  })
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "fe2-alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-alb-sg"
  })
}

resource "aws_security_group_rule" "alb_http_ingress" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "Allow HTTP traffic from anywhere"

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_https_ingress" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "Allow HTTPS traffic from anywhere"

  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_egress_all" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  description       = "Allow all outbound traffic"

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "app" {
  name        = "fe2-sg"
  description = "Allow traffic to FE2 app from ALB and EFS"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-app-sg"
  })
}

resource "aws_security_group" "db" {
  name        = "mongodb-sg"
  description = "Allow traffic to MongoDB from App SG and EFS"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-mongodb-sg"
  })
}

resource "aws_security_group" "efs" {
  name        = "fe2-efs-sg"
  description = "Allow NFS traffic for EFS"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-efs-sg"
  })
}

resource "aws_security_group" "ecr_endpoints" {
  name        = "${local.project_name}-ecr-endpoints-sg"
  description = "Allow HTTPS from ECS tasks to interface endpoints"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-ecr-endpoints-sg"
  })
}

resource "aws_security_group_rule" "ecr_endpoint_https_from_app" {
  type                     = "ingress"
  description              = "Allow HTTPS from app tasks"
  security_group_id        = aws_security_group.ecr_endpoints.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ecr_endpoint_https_from_db" {
  type                     = "ingress"
  description              = "Allow HTTPS from MongoDB tasks"
  security_group_id        = aws_security_group.ecr_endpoints.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ecr_endpoint_https_egress" {
  type              = "egress"
  description       = "Allow return traffic from interface endpoints"
  security_group_id = aws_security_group.ecr_endpoints.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "db_egress_ecr" {
  type                     = "egress"
  description              = "Allow MongoDB tasks to reach interface endpoints over HTTPS"
  security_group_id        = aws_security_group.db.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecr_endpoints.id

  lifecycle {
    create_before_destroy = true
  }
}
