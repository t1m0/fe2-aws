data "aws_ami" "amazon_linux_2023" {
  count       = var.bastion
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "tls_private_key" "bastion" {
  count     = var.bastion
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion" {
  count      = var.bastion
  key_name   = "${local.project_name}-bastion-key"
  public_key = tls_private_key.bastion[0].public_key_openssh
}

resource "local_file" "bastion_key" {
  count           = var.bastion
  content         = tls_private_key.bastion[0].private_key_pem
  filename        = "${path.module}/bastion-key.pem"
  file_permission = "0400"
}

resource "aws_security_group" "bastion" {
  count       = var.bastion
  name        = "${local.project_name}-bastion-sg"
  description = "Allow SSH to bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow Bastion to access EFS
resource "aws_security_group_rule" "efs_ingress_from_bastion" {
  count                    = var.bastion
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = aws_security_group.bastion[0].id
  description              = "Allow NFS traffic from Bastion"
}

resource "aws_instance" "bastion" {
  count                       = var.bastion
  ami                         = data.aws_ami.amazon_linux_2023[0].id
  instance_type               = "t2.nano"
  subnet_id                   = aws_subnet.public[0].id
  key_name                    = aws_key_pair.bastion[0].key_name
  vpc_security_group_ids      = [aws_security_group.bastion[0].id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum install -y amazon-efs-utils
              mkdir -p /mnt/efs
              mount -t efs ${aws_efs_file_system.main[0].id}:/ /mnt/efs
              echo "${aws_efs_file_system.main[0].id}:/ /mnt/efs efs _netdev,tls 0 0" >> /etc/fstab
              EOF

  tags = {
    Name = "${local.project_name}-bastion"
  }
}

#output "bastion_ssh_command" {
#  value = "ssh -i ${local_file.bastion_key.filename} ec2-user@${aws_instance.bastion.public_ip}"
#}
