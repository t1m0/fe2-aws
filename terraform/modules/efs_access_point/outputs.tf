output "id" {
  description = "Access point ID"
  value       = aws_efs_access_point.efs_access_point.id
}

output "arn" {
  description = "Access point ARN"
  value       = aws_efs_access_point.efs_access_point.arn
}
