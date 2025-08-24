variable "aws_region" {
  type = string
}

variable "ecs_cluster_id" {
  type = string
}

variable "name" {
  type = string
}

variable "image" {
  type = string
}

variable "cpu" {
  type    = number
  default = 512
}

variable "memory" {
  type    = number
  default = 1024
}

variable "task_execution_role_arn" {
  type = string
}

variable "alb_arn" {
  type    = string
  default = null
}

variable "port" {
  type = number
}

variable "service_registry_arn" {
  description = "The ARN of the Service Discovery service to register with. If null, no registration occurs."
  type        = string
  default     = null
}

variable "subnets" {
  type    = list(string)
  default = []
}

variable "security_groups" {
  type    = list(string)
  default = []
}

variable "environment" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "mountPoints" {
  type = list(object({
    sourceVolume  = string
    containerPath = string
    readOnly      = bool
  }))
  default = []
}

variable "file_system_id" {
  type    = string
  default = ""
}

variable "volumes" {
  description = "A list of volume definitions for the task, typically for EFS."
  type = list(object({
    name            = string
    access_point_id = string
  }))
  default = []
}

variable "health_check_grace_period_seconds" {
  type    = number
  default = 0
}

variable "log_retention_days" {
  description = "Retention period for CloudWatch logs in days"
  type        = number
  default     = 14
}
