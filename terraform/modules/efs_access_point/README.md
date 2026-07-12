# EFS Access Point Module

Provisions an AWS EFS access point with optional POSIX ownership overrides and default directory permissions. Marks the resource as `prevent_destroy` to guard against accidental deletion.

## Usage

```hcl
module "logs_access_point" {
  source         = "./modules/efs_access_point"
  file_system_id = aws_efs_file_system.main.id
  path           = "/app/logs"
  tags           = local.common_tags
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| file_system_id | ID of the EFS file system to attach the access point to | `string` | n/a |
| path | Directory path created for the access point root | `string` | n/a |
| group_id | POSIX group ID assigned to the access point owner | `number` | `1000` |
| user_id | POSIX user ID assigned to the access point owner | `number` | `1000` |
| permissions | File system permissions for the root directory | `string` | `"0755"` |
| tags | Tags applied to the access point | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| id | Access point ID |
| arn | Access point ARN |

## Version Compatibility

- Terraform `~> 1.15.0`
- AWS provider `hashicorp/aws ~> 6.54.0`
