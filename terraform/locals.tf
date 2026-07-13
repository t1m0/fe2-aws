locals {
  alb_enable_deletion_protection = coalesce(var.alb_enable_deletion_protection, var.environment == "prod")
  alb_access_logs_enabled = coalesce(
    var.alb_access_logs_enabled,
    var.environment == "prod" && var.alb_access_logs_bucket != null
  )

  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = local.project_name
    Owner       = var.owner
  }
}
