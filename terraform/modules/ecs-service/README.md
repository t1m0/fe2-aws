# ECS Service Module

Creates an ECS Fargate service with a single task definition, CloudWatch Logs group, task IAM role, and optional integrations for load balancers, EFS volumes, and Cloud Map registration.

## Usage

```hcl
module "example_service" {
  source                  = "./modules/ecs-service"
  aws_region              = var.aws_region
  name                    = "example"
  image                   = "123456789012.dkr.ecr.us-east-1.amazonaws.com/example:latest"
  task_execution_role_arn = aws_iam_role.ecs_task_execution.arn
  ecs_cluster_id          = aws_ecs_cluster.main.id
  subnets                 = aws_subnet.private[*].id
  security_groups         = [aws_security_group.app.id]
  ports = [{
    port    = 8080
    alb_arn = aws_lb_target_group.app.arn
  }]
  tags = local.common_tags
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| aws_region | AWS region where the ECS service runs | `string` | n/a |
| ecs_cluster_id | ID of the ECS cluster to attach the service to | `string` | n/a |
| name | Short name applied to resources (log group, task family, service) | `string` | n/a |
| image | Container image (including tag) for the task definition | `string` | n/a |
| cpu | Fargate CPU units for the task | `number` | `512` |
| memory | Fargate memory (MB) for the task | `number` | `1024` |
| task_execution_role_arn | IAM execution role ARN used by the task | `string` | n/a |
| ports | List of container ports, optional ALB target group ARNs | `list(object)` | `[]` |
| service_registry_arn | Cloud Map service ARN for service discovery registration | `string` | `null` |
| subnets | Private subnets for the ECS service ENIs | `list(string)` | `[]` |
| security_groups | Security groups assigned to the ECS service ENIs | `list(string)` | `[]` |
| environment | Environment variables injected into the container | `list(object)` | `[]` |
| mountPoints | Container mount point definitions (camelCase retained for compatibility) | `list(object)` | `[]` |
| file_system_id | EFS file system ID backing any declared volumes | `string` | `""` |
| volumes | EFS access point volume definitions referenced by mount points | `list(object)` | `[]` |
| health_check_grace_period_seconds | Seconds ECS waits before evaluating target health | `number` | `0` |
| log_retention_days | CloudWatch Logs retention period in days | `number` | `14` |
| health_check | Optional container health check override | `object` | `null` |
| deployment_maximum_percent | Upper bound percentage of tasks running during deployment | `number` | `200` |
| deployment_minimum_healthy_percent | Lower bound percentage of healthy tasks during deployment | `number` | `100` |
| availability_zone_rebalancing | Fargate availability zone rebalancing setting | `string` | `"ENABLED"` |
| force_new_deployment | Forces service redeployment on each apply when true | `bool` | `false` |
| stop_timeout | Seconds to wait for graceful container shutdown | `number` | `30` |
| command | Override container CMD | `list(string)` | `null` |
| enable_circuit_breaker | Enable ECS deployment circuit breaker with automatic rollback | `bool` | `false` |
| cpu_architecture | CPU architecture for the Fargate task | `string` | `"X86_64"` |
| enable_execute_command | Enable ECS Execute Command for debugging | `bool` | `false` |
| tags | Tags applied to taggable ECS resources | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| service_name | Name of the ECS service |
| task_definition_arn | ARN of the registered task definition |
| log_group_name | CloudWatch Logs group used by the service |

## Version Compatibility

- Terraform `~> 1.15.0`
- AWS provider `hashicorp/aws ~> 6.54.0`

## Notes

- Variable `mountPoints` retains camelCase for backward compatibility with existing module consumers.
