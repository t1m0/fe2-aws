locals {
  ecr_dns = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  common_tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
    Project     = local.project_name
    Owner       = var.owner
  }
}
