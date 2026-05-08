output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs passed to ROSA (workers + masters)"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "public_subnet_id" {
  description = "Public subnet ID (NAT Gateway)"
  value       = aws_subnet.public_a.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.this.id
}

output "vpc_endpoint_s3_id" {
  description = "S3 Gateway endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}
