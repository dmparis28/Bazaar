# --- MODULE: VPC ---
# Defines our private, isolated network.

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# --- SUBNETS ---
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-b"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-private-b"
  }
}

resource "aws_subnet" "cde_private_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.20.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-cde-private-a"
  }
}

resource "aws_subnet" "cde_private_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.21.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-cde-private-b"
  }
}

# --- CONNECTIVITY ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_eip" "nat_eip_a" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw_a" {
  allocation_id = aws_eip.nat_eip_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "${var.name_prefix}-nat-gw-a"
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_eip" "nat_eip_b" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw_b" {
  allocation_id = aws_eip.nat_eip_b.id
  subnet_id     = aws_subnet.public_b.id

  tags = {
    Name = "${var.name_prefix}-nat-gw-b"
  }
  depends_on = [aws_internet_gateway.igw]
}

# --- ROUTING ---
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt_a" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_a.id
  }

  tags = {
    Name = "${var.name_prefix}-private-rt-a"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt_a.id
}

resource "aws_route_table_association" "cde_private_a" {
  subnet_id      = aws_subnet.cde_private_a.id
  route_table_id = aws_route_table.private_rt_a.id
}

resource "aws_route_table" "private_rt_b" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_b.id
  }

  tags = {
    Name = "${var.name_prefix}-private-rt-b"
  }
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt_b.id
}

resource "aws_route_table_association" "cde_private_b" {
  subnet_id      = aws_subnet.cde_private_b.id
  route_table_id = aws_route_table.private_rt_b.id
}

