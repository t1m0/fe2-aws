output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.ecs.name
}

output "task_definition_arn" {
  description = "ARN of the registered task definition"
  value       = aws_ecs_task_definition.ecs.arn
}

output "log_group_name" {
  description = "CloudWatch Logs group used by the service"
  value       = aws_cloudwatch_log_group.ecs.name
}
