# ═══════════════════════════════════════════════════════════════════════════
# VPC in Account B
# ═══════════════════════════════════════════════════════════════════════════
resource "aws_vpc" "main_b" {
  provider             = aws.account_b
  cidr_block           = var.cidr_account_b
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc-${var.environment}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main_b" {
  provider = aws.account_b
  vpc_id   = aws_vpc.main_b.id

  tags = {
    Name = "${var.project_name}-igw-${var.environment}"
  }
}

# Public Subnets
resource "aws_subnet" "public_b" {
  provider                = aws.account_b
  count                   = length(var.public_subnet_cidrs_b)
  vpc_id                  = aws_vpc.main_b.id
  cidr_block              = var.public_subnet_cidrs_b[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}-${var.environment}"
    Type = "Public"
  }
}

# Private Subnets
resource "aws_subnet" "private_b" {
  provider          = aws.account_b
  count             = length(var.private_subnet_cidrs_b)
  vpc_id            = aws_vpc.main_b.id
  cidr_block        = var.private_subnet_cidrs_b[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}-${var.environment}"
    Type = "Private"
  }
}

# NAT Gateway
resource "aws_eip" "nat_b" {
  provider = aws.account_b
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${var.environment}"
  }
}

resource "aws_nat_gateway" "main_b" {
  provider      = aws.account_b
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b[0].id

  tags = {
    Name = "${var.project_name}-nat-${var.environment}"
  }
}

# Public Route Table
resource "aws_route_table" "public_b" {
  provider = aws.account_b
  vpc_id   = aws_vpc.main_b.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_b.id
  }

  tags = {
    Name = "${var.project_name}-public-rt-${var.environment}"
  }
}

# Private Route Table (will also contain peering route)
resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main_b.id
  tags = {
    Name = "${var.project_name}-private-rt-${var.environment}"
  }
}
resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main_b.id
}

# Route Table Associations
resource "aws_route_table_association" "public_b" {
  provider       = aws.account_b
  count          = length(aws_subnet.public_b)
  subnet_id      = aws_subnet.public_b[count.index].id
  route_table_id = aws_route_table.public_b.id
}

resource "aws_route_table_association" "private_b" {
  provider       = aws.account_b
  count          = length(aws_subnet.private_b)
  subnet_id      = aws_subnet.private_b[count.index].id
  route_table_id = aws_route_table.private_b.id
}

# Availability Zones data
data "aws_availability_zones" "available" {
  provider = aws.account_b
  state    = "available"
}