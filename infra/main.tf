# --- Phase 0, Step 2: Cloud Provider & VPC ---
# This Terraform file defines the core network for Project Bazaar on AWS.
# It creates the VPC, all subnets, and the necessary routing
# to match our "Comprehensive Architecture Guide".

# 1. CONFIGURE THE AWS PROVIDER
# We specify the AWS region we want to build in.
provider "aws" {
  region = "us-east-1"
}

# [Terraform EKS Module - This simplifies EKS creation significantly]
# We add the "eks" provider which helps us configure the cluster.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # EKS module requires these for auth
    http = {
      source  = "hashicorp/http"
      version = "2.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.11.0"
    }
  }
}

# 2. CREATE THE VIRTUAL PRIVATE CLOUD (VPC)
# This is our main, isolated network. Everything lives inside this.
resource "aws_vpc" "bazaar_vpc" {
  cidr_block = "10.0.0.0/16" # A large, private IP range for our app
  # Enable DNS support, required by EKS
  enable_dns_support   = true
  enable_dns_hostnames = true

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

resource "aws_eip" "nat_eip_a" {
  domain = "vpc"
}
# We create a NAT Gateway in EACH Availability Zone for High Availability
resource "aws_nat_gateway" "bazaar_nat_gw_a" {
  allocation_id = aws_eip.nat_eip_a.id
  subnet_id     = aws_subnet.public_a.id # NAT gateway lives in a public subnet
  depends_on    = [aws_internet_gateway.bazaar_igw]

  tags = {
    Name = "bazaar-nat-gw-a"
  }
}

resource "aws_eip" "nat_eip_b" {
  domain = "vpc"
}
resource "aws_nat_gateway" "bazaar_nat_gw_b" {
  allocation_id = aws_eip.nat_eip_b.id
  subnet_id     = aws_subnet.public_b.id
  depends_on    = [aws_internet_gateway.bazaar_igw]

  tags = {
    Name = "bazaar-nat-gw-b"
  }
}


# 5. DEFINE OUR SUBNETS (ACROSS TWO AVAILABILITY ZONES FOR HIGH AVAILABILITY)
# We create two of each type, one in 'us-east-1a' and one in 'us-east-1b'.
# This is the "Multi-AZ Deployment" from your resilience guide.

# --- Public Subnets (for Load Balancers) ---
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.bazaar_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # Public IPs are allowed here

  tags = {
    Name = "bazaar-public-subnet-a"
    # EKS tags required for Load Balancer discovery
    "kubernetes.io/cluster/bazaar-cluster" = "shared"
    "kubernetes.io/role/elb"               = "1"
  }
}
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.bazaar_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "bazaar-public-subnet-b"
    # EKS tags required for Load Balancer discovery
    "kubernetes.io/cluster/bazaar-cluster" = "shared"
    "kubernetes.io/role/elb"               = "1"
  }
}

# --- Private Subnets (for most Microservices) ---
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.bazaar_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "bazaar-private-subnet-a"
    # EKS tags required for internal Load Balancers
    "kubernetes.io/cluster/bazaar-cluster" = "shared"
    "kubernetes.io/role/internal-elb"      = "1"
  }
}
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.bazaar_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "bazaar-private-subnet-b"
    # EKS tags required for internal Load Balancers
    "kubernetes.io/cluster/bazaar-cluster" = "shared"
    "kubernetes.io/role/internal-elb"      = "1"
  }
}

# --- CDE Private Subnets (for SAQ D Payment Service) ---
resource "aws_subnet" "cde_private_a" {
  vpc_id            = aws_vpc.bazaar_vpc.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "bazaar-CDE-private-subnet-a"
    # EKS tags for discovery
    "kubernetes.io/cluster/bazaar-cluster" = "shared"
    "kubernetes.io/role/internal-elb"      = "1"
  }
}
resource "aws_subnet" "cde_private_b" {
  vpc_id            = aws_vpc.bazaar_vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "bazaar-CDE-private-subnet-b"
    # EKS tags for discovery
    "kubernetes.io/cluster/bazaar-cluster" = "shared"
    "kubernetes.io/role/internal-elb"      = "1"
  }
}

# 6. CONFIGURE ROUTING (THE "VIRTUAL WIRING")

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
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

# --- Private Route Table 'A' (Routes to NAT Gateway 'A') ---
resource "aws_route_table" "private_rt_a" {
  vpc_id = aws_vpc.bazaar_vpc.id

  route {
    cidr_block     = "0.0.0.0/0" # Any internet address
    nat_gateway_id = aws_nat_gateway.bazaar_nat_gw_a.id
  }

  tags = {
    Name = "bazaar-private-rt-a"
  }
}
# Associate all 'a' subnets
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt_a.id
}
resource "aws_route_table_association" "cde_private_a" {
  subnet_id      = aws_subnet.cde_private_a.id
  route_table_id = aws_route_table.private_rt_a.id
}

# --- Private Route Table 'B' (Routes to NAT Gateway 'B') ---
resource "aws_route_table" "private_rt_b" {
  vpc_id = aws_vpc.bazaar_vpc.id

  route {
    cidr_block     = "0.0.0.0/0" # Any internet address
    nat_gateway_id = aws_nat_gateway.bazaar_nat_gw_b.id
  }

  tags = {
    Name = "bazaar-private-rt-b"
  }
}
# Associate all 'b' subnets
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt_b.id
}
resource "aws_route_table_association" "cde_private_b" {
  subnet_id      = aws_subnet.cde_private_b.id
  route_table_id = aws_route_table.private_rt_b.id
}


###############################################################
# --- PHASE 0, STEP 3: EKS KUBERNETES CLUSTER ---
###############################################################

# 7. IAM ROLES FOR EKS
# We need to create an IAM Role for the EKS Cluster itself...
resource "aws_iam_role" "eks_cluster_role" {
  name = "bazaar-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}
# ...and attach the required AWS-managed policy to it.
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# We also create an IAM Role for the worker nodes (servers).
resource "aws_iam_role" "eks_node_role" {
  name = "bazaar-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}
# ...and attach the required policies for nodes.
resource "aws_iam_role_policy_attachment" "eks_node_policy_1" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}
resource "aws_iam_role_policy_attachment" "eks_node_policy_2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}
resource "aws_iam_role_policy_attachment" "eks_node_policy_3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}


# 8. KMS KEY FOR KUBERNETES SECRETS ENCRYPTION
# (Security) We create our own key to encrypt K8s secrets.
resource "aws_kms_key" "eks_secrets_key" {
  description             = "KMS key for encrypting EKS secrets"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

# 9. THE EKS CLUSTER
# This is the "control plane" or brain of our cluster.
resource "aws_eks_cluster" "bazaar_cluster" {
  name     = "bazaar-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  # (Security) We make this a PRIVATE cluster.
  # The API server is not exposed to the public internet.
  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
      aws_subnet.cde_private_a.id,
      aws_subnet.cde_private_b.id
    ]
    endpoint_private_access = true
    endpoint_public_access  = false # MOTTO: Security & Trust
  }

  # (Security) Encrypt K8s secrets using our new key.
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets_key.arn
    }
    resources = ["secrets"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}

# 10. EKS NODE GROUPS (THE WORKERS)

# --- General Purpose Node Group ---
# For our non-sensitive microservices (user, product, etc.)
resource "aws_eks_node_group" "general_nodes" {
  cluster_name    = aws_eks_cluster.bazaar_cluster.name
  node_group_name = "general-purpose-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  # (HA) We deploy nodes into our Multi-AZ private subnets
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  instance_types = ["t3.medium"] # Good general purpose instances
  scaling_config {
    desired_size = 2 # Start with 2 nodes
    min_size     = 1
    max_size     = 5 # (Scalability) Will scale up to 5 nodes
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy_1,
    aws_iam_role_policy_attachment.eks_node_policy_2,
    aws_iam_role_policy_attachment.eks_node_policy_3,
  ]
}

# --- CDE (Cardholder Data Environment) Node Group ---
# (Security) A dedicated, isolated node group for our payment-service
resource "aws_eks_node_group" "cde_nodes" {
  cluster_name    = aws_eks_cluster.bazaar_cluster.name
  node_group_name = "cde-secure-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  # (Security) These nodes ONLY live in our CDE-specific subnets
  subnet_ids = [
    aws_subnet.cde_private_a.id,
    aws_subnet.cde_private_b.id
  ]

  instance_types = ["t3.medium"]
  scaling_config {
    desired_size = 2 # (HA) Always have 2 nodes for the payment service
    min_size     = 1
    max_size     = 3
  }

  # (Security: Micro-segmentation)
  # We apply a "Taint" to these nodes. This prevents any other
  # K8s service from being scheduled here by accident.
  # Only pods (like our payment-service) that explicitly
  # "tolerate" this taint can run here.
  taint {
    key    = "security"
    value  = "cde-environment"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "node-type" = "cde-secure-nodes"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy_1,
    aws_iam_role_policy_attachment.eks_node_policy_2,
    aws_iam_role_policy_attachment.eks_TaintToleration.eks_node_policy_3,
  ]
}

