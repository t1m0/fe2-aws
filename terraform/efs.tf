resource "aws_efs_file_system" "main" {
  count            = 1
  creation_token   = "${local.project_name}-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true
}

resource "aws_efs_mount_target" "main" {
  count           = var.az_count
  file_system_id  = aws_efs_file_system.main[0].id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# Security Group Rules
resource "aws_security_group_rule" "efs_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.efs.id
  description       = "Allow all outbound traffic from EFS SG"
}

resource "aws_security_group_rule" "efs_ingress_from_app_and_db" {
  type                     = "ingress"
  from_port                = 2049 # NFS port
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = aws_security_group.app.id
  description              = "Allow EFS traffic from App SG"
}

resource "aws_security_group_rule" "efs_ingress_from_db" {
  type                     = "ingress"
  from_port                = 2049 # NFS port
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = aws_security_group.db.id
  description              = "Allow EFS traffic from DB SG"
}
