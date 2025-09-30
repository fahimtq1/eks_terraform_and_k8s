# Output the VPC ID
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

# Output the public subnet IDs
output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

# Output the private subnet IDs
output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

# Output the EKS cluster endpoint
output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = aws_eks_cluster.main.endpoint
}

# Output the EKS cluster name
output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

# NEW: Output the IAM role ARN for the worker nodes
output "node_iam_role_arn" {
  description = "The ARN of the IAM role for the EKS worker nodes"
  value       = aws_iam_role.eks_nodes.arn
}

# Output the RDS database endpoint
output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

# Output the DocumentDB endpoint
output "docdb_endpoint" {
  description = "The endpoint of the DocumentDB cluster"
  value       = aws_docdb_cluster.main.endpoint
  sensitive   = true
}

