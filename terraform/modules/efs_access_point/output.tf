output "id" {
  value      = aws_efs_access_point.efs_access_point.id
  depends_on = [aws_efs_access_point.efs_access_point]
}
