resource "aws_efs_access_point" "efs_access_point" {
  file_system_id = var.file_system_id
  posix_user {
    gid = var.group_id
    uid = var.user_id
  }
  root_directory {
    path = var.path
    creation_info {
      owner_gid   = var.group_id
      owner_uid   = var.user_id
      permissions = var.permissions
    }
  }
}
