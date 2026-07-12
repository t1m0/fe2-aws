variable "fe2_registry_email" {
  type = string
}

variable "fe2_registry_password" {
  type      = string
  sensitive = true
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to use"
  type        = number
  default     = 2
}

variable "owner" {
  description = "Owner tag applied to network resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment name used for tagging and environment-specific defaults"
  type        = string
  default     = "prod"
}

variable "alb_enable_deletion_protection" {
  description = "Override for ALB deletion protection; defaults to enabled in production"
  type        = bool
  default     = null
}

variable "alb_access_logs_enabled" {
  description = "Override for ALB access logs; defaults to enabled in production"
  type        = bool
  default     = null
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket name for ALB access logs"
  type        = string
  default     = null
}

variable "alb_access_logs_prefix" {
  description = "Optional prefix for ALB access logs within the destination bucket"
  type        = string
  default     = null
}
