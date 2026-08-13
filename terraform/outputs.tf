output "vpc_name" {
  value = aws_vpc.main.tags["Name"]
}

output "public_subnet_names" {
  value = [for subnet in aws_subnet.public : subnet.tags["Name"]]
}

output "private_subnet_names" {
  value = [for subnet in aws_subnet.private : subnet.tags["Name"]]
}

output "nat_gateway_names" {
  value = [for nat in aws_nat_gateway.main : nat.tags["Name"]]
}

output "nat_eip_names" {
  value = [for eip in aws_eip.nat : eip.tags["Name"]]
}

output "public_route_table_name" {
  value = aws_route_table.public.tags["Name"]
}

output "private_route_table_names" {
  value = [for rt in aws_route_table.private : rt.tags["Name"]]
}

output "interface_vpc_endpoint_ids" {
  description = "Interface endpoint IDs for private ECR/S3 access"
  value = {
    ecr_api = aws_vpc_endpoint.ecr_api.id
    ecr_dkr = aws_vpc_endpoint.ecr_dkr.id
    s3      = aws_vpc_endpoint.s3_interface.id
  }
}
