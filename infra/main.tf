# --- Phase 0, Step 2: Cloud Provider & VPC ---
# This Terraform file defines the core network for Project Bazaar on AWS.
# It creates the VPC, all subnets, and the necessary routing
# to match our "Comprehensive Architecture Guide".

# 1. CONFIGURE THE AWS PROVIDER
# We specify the AWS region we want to build in.
provider "aws" {
  region = "us-east-1"
}

# 2. CREATE THE VIRTUAL PRIVATE CLOUD (VPC)
# This is our main, isolated network. Everything lives inside this.
resource "aws_vpc" "bazaar_vpc" {
  cidr_block = "10.0.0.0/16" # A large, private IP range for our app

  tags = {
    Name = "bazaar-vpc"
  }
}

# 3. SET UP INTERNET CONNECTIVITY FOR PUBLIC SUBNETS
# An Internet Gateway (IGW) allows our public subnets to talk to the internet.
resource "aws_internet_gateway" "bazaar_igw" {
  vpc_id = aws_vpc.bazaar_vpc.id

  tags = {
    Name = "bazaar-igw"
  }
}

# 4. SET UP INTERNET CONNECTIVITY FOR PRIVATE SUBNETS
# Our private subnets CANNOT be reached from the internet.
# But they need to get OUT to the internet (e.g., to pull container images).
# A NAT Gateway (with an Elastic IP) allows this one-way communication.

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "bazaar_nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id # NAT gateway lives in a public subnet
  depends_on    = [aws_internet_gateway.bazaar_igw]

  tags = {
    Name = "bazaar-nat-gw"
  }
}

# 5. DEFINE OUR SUBNETS (ACROSS TWO AVAILABILITY ZONES FOR HIGH AVAILABILITY)
# We create two of each type, one in 'us-east-1a' and one in 'us-east-1b'.
# This is the "Multi-AZ Deployment" from your resilience guide.

# --- Public Subnets (for Load Balancers) ---
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.bazaar_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true # Public IPs are allowed here

  tags = {
    Name = "bazaar-public-subnet-a"
  }
}
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.bazaar_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "bazaar-public-subnet-b"
  }
}

# --- Private Subnets (for most Microservices) ---
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.bazaar_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "bazaar-private-subnet-a"
  }
}
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.bazaar_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "bazaar-private-subnet-b"
  }
}

# --- CDE Private Subnets (for SAQ D Payment Service) ---
# These are functionally the same as 'private' subnets, but we create them
# separately so we can apply EXTREMELY strict security (micro-segmentation)
# to them later.
resource "aws_subnet" "cde_private_a" {
  vpc_id            = aws_vpc.bazaar_vpc.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "bazaar-CDE-private-subnet-a"
  }
}
resource "aws_subnet" "cde_private_b" {
  vpc_id            = aws_vpc.bazaar_vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "bazaar-CDE-private-subnet-b"
  }
}

# 6. CONFIGURE ROUTING (THE "VIRTUAL WIRING")
# This tells traffic how to move around our VPC.

# --- Public Route Table (Traffic to 0.0.0.0/0 goes to the Internet Gateway) ---
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.bazaar_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Any internet address
    gateway_id = aws_internet_gateway.bazaar_igw.id
  }

  tags = {
    Name = "bazaar-public-rt"
  }
}
# Associate our public subnets with this route table
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

# --- Private Route Table (Traffic to 0.0.0.0/0 goes to the NAT Gateway) ---
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.bazaar_vpc.id

  route {
    cidr_block     = "0.0.0.0/0" # Any internet address
    nat_gateway_id = aws_nat_gateway.bazaar_nat_gw.id
  }

  tags = {
    Name = "bazaar-private-rt"
  }
}
# Associate all our private subnets (both regular and CDE) with this table
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "cde_private_a" {
  subnet_id      = aws_subnet.cde_private_a.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "cde_private_b" {
  subnet_id      = aws_subnet.cde_private_b.id
  route_table_id = aws_route_table.private_rt.id
}

