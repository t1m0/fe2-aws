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

variable "bastion" {
  type    = number
  default = 0
}
