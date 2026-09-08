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

output "subnets_by_az" {
  description = <<-EOT
    Map of AZ name -> subnet id, e.g. { "ap-south-1a" = "subnet-abc" }.

    Exists so the node group can be PINNED to one AZ. An EBS volume lives in
    exactly one AZ, and so must the pod that mounts it -- so a single-node
    cluster whose node might come up in either AZ cannot reliably reattach a
    Postgres volume after a scale-down to 0.
  EOT
  value       = { for az, s in aws_subnet.public : az => s.id }
}
