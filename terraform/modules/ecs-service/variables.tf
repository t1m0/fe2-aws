variable "aws_region" {
  description = "AWS region where the ECS service runs"
  type        = string
  nullable    = false
}

variable "ecs_cluster_id" {
  description = "ID of the ECS cluster to attach the service to"
  type        = string
  nullable    = false
}

variable "name" {
  description = "Short name applied to resources (log group, task family, service)"
  type        = string
  nullable    = false
}

variable "image" {
  description = "Container image (including tag) for the task definition"
  type        = string
  nullable    = false
}

variable "cpu" {
  description = "Fargate CPU units for the task"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Fargate memory (MB) for the task"
  type        = number
  default     = 1024
}

variable "task_execution_role_arn" {
  description = "IAM execution role ARN used by the task"
  type        = string
  nullable    = false
}

variable "ports" {
  description = "List of container ports, with optional ALB target group ARNs for attachments"
  type = list(object({
    port    = number
    alb_arn = optional(string, null)
  }))
  default = []
}

variable "service_registry_arn" {
  description = "Cloud Map service ARN for service discovery registration"
  type        = string
  default     = null
}

variable "subnets" {
  description = "Private subnets for the ECS service ENIs"
  type        = list(string)
  default     = []
}

variable "security_groups" {
  description = "Security groups assigned to the ECS service ENIs"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment variables injected into the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "mountPoints" {
  description = "Container mount point definitions (camelCase retained for compatibility)"
  type = list(object({
    sourceVolume  = string
    containerPath = string
    readOnly      = bool
  }))
  default = []
}

variable "file_system_id" {
  description = "EFS file system ID backing any declared volumes"
  type        = string
  default     = ""
}

variable "volumes" {
  description = "EFS access point volume definitions referenced by mount points"
  type = list(object({
    name            = string
    access_point_id = string
  }))
  default = []
}

variable "health_check_grace_period_seconds" {
  description = "Seconds ECS waits before evaluating target health during deployment"
  type        = number
  default     = 0
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 14
}

variable "health_check" {
  description = "Optional container health check override"
  type = object({
    command     = list(string)
    interval    = number
    timeout     = number
    retries     = number
    startPeriod = number
  })
  default = null
}

variable "deployment_maximum_percent" {
  description = "Upper bound percentage of tasks running during a deployment"
  type        = number
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower bound percentage of tasks that must remain healthy during deployment"
  type        = number
  default     = 100
}

variable "availability_zone_rebalancing" {
  description = "Fargate availability zone rebalancing setting"
  type        = string
  default     = "ENABLED"
}

variable "force_new_deployment" {
  description = "Forces service redeployment on each apply when true"
  type        = bool
  default     = false
}

variable "stop_timeout" {
  description = "Seconds to wait for graceful container shutdown before force kill"
  type        = number
  default     = 30
}

variable "command" {
  description = "Override container CMD"
  type        = list(string)
  default     = null
}

variable "enable_circuit_breaker" {
  description = "Enable ECS deployment circuit breaker with automatic rollback"
  type        = bool
  default     = false
}

variable "cpu_architecture" {
  description = "CPU architecture for the Fargate task"
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be either X86_64 or ARM64."
  }
}

variable "enable_execute_command" {
  description = "Enable ECS Execute Command for debugging"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to taggable ECS resources"
  type        = map(string)
  default     = {}
}
