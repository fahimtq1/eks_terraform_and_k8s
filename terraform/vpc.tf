
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true


  tags = {
    Name = "fintech-vpc"
  }
}


// Provides an Internet Gateway for the VPC to allow communication with the internet.
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id


  tags = {
    Name = "fintech-igw"
  }
}

data "aws_availability_zones" "available" {}


resource "aws_subnet" "public" {
  count                   = 2 // Using 2 for simplicity and cost, can be length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true


  tags = {
    Name                                = "fintech-public-subnet-${count.index + 1}"
    "kubernetes.io/cluster/fintech-cluster" = "shared" // Tag for EKS auto-discovery
    "kubernetes.io/role/elb"            = "1"
  }
}


resource "aws_subnet" "private" {
  count             = 2 // Using 2 for simplicity
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + length(aws_subnet.public))
  availability_zone = data.aws_availability_zones.available.names[count.index]


  tags = {
    Name                                = "fintech-private-subnet-${count.index + 1}"
    "kubernetes.io/cluster/fintech-cluster" = "shared" // Tag for EKS auto-discovery
    "kubernetes.io/role/internal-elb"   = "1"
  }
}


resource "aws_eip" "nat" {
  domain = "vpc"
}


resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id


  tags = {
    Name = "fintech-nat-gateway"
  }


  depends_on = [aws_internet_gateway.gw]
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }


  tags = {
    Name = "fintech-public-rt"
  }
}


resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id


  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }


  tags = {
    Name = "fintech-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}