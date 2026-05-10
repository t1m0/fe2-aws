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

variable "health_check" {
  description = "Container health check configuration"
  type = object({
    command     = list(string)
    interval    = number
    timeout     = number
    retries     = number
    startPeriod = number
  })
  default = null
}

variable "restart_policy" {
  description = "Service restart policy configuration"
  type = object({
    max_percent             = number
    min_percent             = number
    circuit_breaker_enabled = bool
  })
  default = null
}

variable "deployment_maximum_percent" {
  type    = number
  default = 200
}

variable "deployment_minimum_healthy_percent" {
  type    = number
  default = 100
}

variable "availability_zone_rebalancing" {
  type    = string
  default = "ENABLED"
}

variable "force_new_deployment" {
  description = "Force a new deployment on every apply. Set to false for stateful services like databases."
  type        = bool
  default     = false
}

variable "stop_timeout" {
  description = "Time in seconds to wait for the container to stop gracefully before it is forcefully killed. Increase for stateful services."
  type        = number
  default     = 30
}

variable "command" {
  description = "Override the default command (CMD) for the container."
  type        = list(string)
  default     = null
}

variable "enable_circuit_breaker" {
  description = "Enable ECS deployment circuit breaker with automatic rollback on failure."
  type        = bool
  default     = false
}

variable "cpu_architecture" {
  description = "CPU architecture for the Fargate task. Must match the architecture of the container image. Valid values: X86_64, ARM64."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be either X86_64 or ARM64."
  }
}

variable "enable_execute_command" {
  description = "Enable ECS Execute Command for interactive debugging. Requires SSM VPC endpoints in the subnets."
  type        = bool
  default     = false
}
