output "vpc_id" {
  description = "VPC id, consumed by the eks module."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet ids. Both the control plane and the node group use these."
  value       = [for s in aws_subnet.public : s.id]
}

output "availability_zones" {
  description = "AZs the subnets were created in."
  value       = [for s in aws_subnet.public : s.availability_zone]
}
