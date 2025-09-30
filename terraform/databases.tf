# terraform/databases.tf

# --- PostgreSQL (RDS) ---

# Define a security group for the PostgreSQL database
resource "aws_security_group" "rds_sg" {
  name        = "fintech-rds-sg"
  description = "Allow traffic to RDS from EKS nodes"
  vpc_id      = aws_vpc.main.id

  # Ingress rule: Allow PostgreSQL traffic from the EKS nodes' security group
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  # Egress rule: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fintech-rds-sg"
  }
}

# Define a subnet group for the RDS instance
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "fintech-rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "Fintech RDS Subnet Group"
  }
}

# Create the RDS instance for PostgreSQL
resource "aws_db_instance" "postgres" {
  identifier             = "fintech-postgres-db"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  # Updated to a recent, supported version
  engine_version         = "16.3"
  instance_class         = "db.t3.micro"
  db_name                = "fintechdb"
  username               = "dbuser"
  password               = "YourSecurePassword123" # Use a more secure password in a real project
  parameter_group_name   = "default.postgres16"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false # Keep the database private
}


# --- DocumentDB (MongoDB Compatible) ---

# Define a security group for the DocumentDB cluster
resource "aws_security_group" "docdb_sg" {
  name        = "fintech-docdb-sg"
  description = "Allow traffic to DocumentDB from EKS nodes"
  vpc_id      = aws_vpc.main.id

  # Ingress rule: Allow DocumentDB traffic (port 27017) from EKS nodes
  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  # Egress rule: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fintech-docdb-sg"
  }
}

# Define a subnet group for the DocumentDB cluster
resource "aws_docdb_cluster" "main" {
  cluster_identifier      = "fintech-docdb-cluster"
  engine                  = "docdb"
  engine_version          = "4.0.0"
  master_username         = "docdbuser" # "admin" is a reserved word
  master_password         = "YourSecurePassword123" # Use a more secure password
  db_subnet_group_name    = aws_docdb_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.docdb_sg.id]
  skip_final_snapshot     = true
  backup_retention_period = 1 # Required, but we can set to minimum
}

# Define the DocumentDB cluster instances
resource "aws_docdb_cluster_instance" "main" {
  count              = 1 # For simplicity, we'll create only one instance
  identifier         = "fintech-docdb-instance-${count.index}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = "db.t3.medium"
}

# Define a subnet group for the DocumentDB cluster
resource "aws_docdb_subnet_group" "main" {
  name       = "fintech-docdb-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "Fintech DocumentDB Subnet Group"
  }
}

