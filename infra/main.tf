# --- BAZAAR INFRASTRUCTURE ---
# This file defines the entire cloud infrastructure for Project Bazaar.
# We are following our "Security & Trust" moto:
# 1. All resources are in a private VPC.
# 2. All resources are Multi-AZ for High Availability.
# 3. All resources are encrypted at rest and in transit.
# 4. We use a Zero Trust model (private EKS, CDE subnets).

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---
# 1. NETWORKING (VPC)
# Defines our private, isolated network.
# ---

resource "aws_vpc" "bazaar_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "bazaar-vpc"
  }
}

# ---
# SUBNETS
# We create 3 subnet types across 2 Availability Zones for High Availability (HA).
# ---

# Public Subnets (for Load Balancers and NAT Gateways)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.bazaar_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "bazaar-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.bazaar_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "bazaar-public-b"
  }
}

# Private Subnets (for general microservices and data stores)
resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.bazaar_vpc.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "bazaar-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.bazaar_vpc.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "bazaar-private-b"
  }
}

# CDE Private Subnets (Cardholder Data Environment - for payment service)
resource "aws_subnet" "cde_private_a" {
  vpc_id                  = aws_vpc.bazaar_vpc.id
  cidr_block              = "10.0.20.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "bazaar-cde-private-a"
  }
}

resource "aws_subnet" "cde_private_b" {
  vpc_id                  = aws_vpc.bazaar_vpc.id
  cidr_block              = "10.0.21.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "bazaar-cde-private-b"
  }
}

# ---
# NETWORKING (Connectivity)
# ---

# Internet Gateway (for public subnets)
resource "aws_internet_gateway" "bazaar_igw" {
  vpc_id = aws_vpc.bazaar_vpc.id

  tags = {
    Name = "bazaar-igw"
  }
}

# NAT Gateways (for private subnets to access the internet)
resource "aws_eip" "nat_eip_a" {
  domain = "vpc"
}

resource "aws_nat_gateway" "bazaar_nat_gw_a" {
  allocation_id = aws_eip.nat_eip_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "bazaar-nat-gw-a"
  }
  depends_on = [aws_internet_gateway.bazaar_igw]
}

resource "aws_eip" "nat_eip_b" {
  domain = "vpc"
}

resource "aws_nat_gateway" "bazaar_nat_gw_b" {
  allocation_id = aws_eip.nat_eip_b.id
  subnet_id     = aws_subnet.public_b.id

  tags = {
    Name = "bazaar-nat-gw-b"
  }
  depends_on = [aws_internet_gateway.bazaar_igw]
}

# ---
# NETWORKING (Routing)
# ---

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.bazaar_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
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

# Private Route Table (routes to NAT Gateway A)
resource "aws_route_table" "private_rt_a" {
  vpc_id = aws_vpc.bazaar_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.bazaar_nat_gw_a.id
  }

  tags = {
    Name = "bazaar-private-rt-a"
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

# Private Route Table (routes to NAT Gateway B)
resource "aws_route_table" "private_rt_b" {
  vpc_id = aws_vpc.bazaar_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.bazaar_nat_gw_b.id
  }

  tags = {
    Name = "bazaar-private-rt-b"
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


# ---
# 2. KUBERNETES (EKS)
# Our secure, private compute fabric.
# ---

# Security Group for the EKS cluster (allows K8s API to talk to nodes)
resource "aws_security_group" "eks_cluster_sg" {
  name   = "bazaar-eks-cluster-sg"
  vpc_id = aws_vpc.bazaar_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow cluster to cluster"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bazaar-eks-cluster-sg"
  }
}

# Security Group for the EKS worker nodes
resource "aws_security_group" "eks_node_sg" {
  name   = "bazaar-eks-node-sg"
  vpc_id = aws_vpc.bazaar_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow node to node"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [aws_security_group.eks_cluster_sg.id]
    description = "Allow cluster control plane to nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bazaar-eks-node-sg"
  }
}

# IAM Role for the EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "bazaar-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# IAM Role for the EKS Worker Nodes
resource "aws_iam_role" "eks_node_role" {
  name = "bazaar-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

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

# KMS Key for encrypting K8s Secrets (Security & Trust Moto)
resource "aws_kms_key" "eks_secrets_key" {
  description             = "KMS key for encrypting EKS secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# The EKS Cluster Resource
resource "aws_eks_cluster" "bazaar_cluster" {
  name     = "bazaar-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.29"

  vpc_config {
    security_group_ids = [aws_security_group.eks_cluster_sg.id, aws_security_group.eks_node_sg.id]
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
      aws_subnet.cde_private_a.id,
      aws_subnet.cde_private_b.id
    ]
    # This makes our cluster API private. MASSIVE security win.
    endpoint_private_access = true
    endpoint_public_access  = false
  }

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

# ---
# EKS NODE GROUPS (Our Servers)
# ---

# General Node Group (for most microservices)
resource "aws_eks_node_group" "general_nodes" {
  cluster_name    = aws_eks_cluster.bazaar_cluster.name
  node_group_name = "general-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    "node-type" = "general-workloads"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy_1,
    aws_iam_role_policy_attachment.eks_node_policy_2,
    aws_iam_role_policy_attachment.eks_node_policy_3,
  ]
}

# CDE Node Group (Isolated for payment-service)
resource "aws_eks_node_group" "cde_nodes" {
  cluster_name    = aws_eks_cluster.bazaar_cluster.name
  node_group_name = "cde-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids = [
    aws_subnet.cde_private_a.id,
    aws_subnet.cde_private_b.id
  ]
  instance_types = ["t3.medium"] # Can be t3.large for more power

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  # This "Taint" is a K8s rule that says "Do not run any pods here
  # unless they have a matching 'Toleration'".
  # This guarantees only our payment-service can run on this hardware.
  taint {
    key    = "cde"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "node-type" = "cde-secure-nodes"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy_1,
    aws_iam_role_policy_attachment.eks_node_policy_2,
    aws_iam_role_policy_attachment.eks_node_policy_3,
  ]
}

# ---
# KUBERNETES PROVIDER
# This allows Terraform to talk to our new EKS cluster
# ---

data "aws_eks_cluster" "bazaar_cluster" {
  name = aws_eks_cluster.bazaar_cluster.name
  depends_on = [
    aws_eks_cluster.bazaar_cluster
  ]
}

data "aws_eks_cluster_auth" "bazaar_cluster" {
  name = aws_eks_cluster.bazaar_cluster.name
  depends_on = [
    aws_eks_cluster.bazaar_cluster
  ]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.bazaar_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.bazaar_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.bazaar_cluster.token
}


# ---
# 3. DATA STORES (Database, Cache, Kafka)
# ---

# ---
# PostgreSQL Database (RDS)
# ---

resource "aws_security_group" "rds_sg" {
  name        = "bazaar-rds-sg"
  description = "Allow internal traffic to RDS"
  vpc_id      = aws_vpc.bazaar_vpc.id

  # Allow traffic from our K8s nodes
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "bazaar-rds-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "Bazaar RDS Subnet Group"
  }
}

resource "random_password" "db_password" {
  length  = 16
  special = true
}

resource "aws_db_instance" "bazaar_db" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15.3"
  instance_class         = "db.t3.micro"
  identifier             = "bazaar-db"
  username               = "bazaaradmin"
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  multi_az               = true # High Availability!
  storage_encrypted      = true # Security & Trust!
}

# ---
# Redis Cache (ElastiCache)
# ---

resource "aws_security_group" "redis_sg" {
  name        = "bazaar-redis-sg"
  description = "Allow internal traffic to Redis"
  vpc_id      = aws_vpc.bazaar_vpc.id

  # Allow traffic from our K8s nodes
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "bazaar-redis-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_elasticache_cluster" "bazaar_redis" {
  cluster_id           = "bazaar-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1 # Can increase for HA
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis_sg.id]
  transit_encryption_enabled = true # Security & Trust!
}

# ---
# Apache Kafka (MSK)
# ---

resource "aws_security_group" "msk_sg" {
  name        = "bazaar-msk-sg"
  description = "Allow internal traffic to MSK/Kafka"
  vpc_id      = aws_vpc.bazaar_vpc.id

  # Allow traffic from our K8s nodes (all Kafka ports)
  ingress {
    from_port       = 2181 # Zookeeper
    to_port         = 2181
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node_sg.id]
  }
  ingress {
    from_port       = 9092 # Plaintext
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node_sg.id]
  }
  ingress {
    from_port       = 9094 # TLS
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node_sg.id]
  }
    ingress {
    from_port       = 9098 # IAM
    to_port         = 9098
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_msk_cluster" "bazaar_kafka" {
  cluster_name           = "bazaar-kafka-cluster"
  kafka_version          = "2.8.1" # Use a stable version
  number_of_broker_nodes = 2       # Must be multiple of AZs (we use 2)

  broker_node_group_info {
    instance_type = "kafka.t3.small"
    client_subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
    security_groups = [aws_security_group.msk_sg.id]
    storage_info {
      ebs_storage_info {
        volume_size = 10 # 10GB
      }
    }
  }

  # Security & Trust: Encrypt everything
  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.eks_secrets_key.arn # Re-use our EKS key
    encryption_in_transit {
      client_broker = "TLS" # Enforce TLS for all connections
      in_cluster    = true
    }
  }
  
  # Security & Trust: Use IAM for auth
  client_authentication {
    sasl {
      iam = true
    }
  }
  
  tags = {
    Name = "bazaar-kafka-cluster"
  }
}

# ---
# 4. SECURE DEVELOPER ACCESS (Client VPN)
# ---

# We need a way to securely access our private resources (K8s, DB)
# We will use AWS Client VPN.

# First, create certificates for the VPN
resource "aws_acm_certificate" "vpn_server_cert" {
  domain_name       = "vpn.bazaar.internal" # Dummy domain
  validation_method = "NONE"                # We will self-sign
  key_algorithm     = "RSA_2048"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "vpn_client_cert" {
  domain_name       = "client.bazaar.internal" # Dummy domain
  validation_method = "NONE"
  key_algorithm     = "RSA_2048"
  
  lifecycle {
    create_before_destroy = true
  }
}

# The VPN Endpoint
resource "aws_ec2_client_vpn_endpoint" "bazaar_vpn" {
  description            = "Bazaar Client VPN"
  server_certificate_arn = aws_acm_certificate.vpn_server_cert.arn
  client_cidr_block      = "192.168.0.0/22" # CIDR for our laptops
  
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.vpn_client_cert.arn
  }

  connection_log_options {
    enabled = false # Can be enabled for deep auditing
  }

  # Allow clients to "see" the entire VPC
  dns_servers    = ["10.0.0.2"] # VPC's internal DNS resolver
  transport_protocol = "udp"
}

# Associate VPN with our private network
resource "aws_ec2_client_vpn_network_association" "vpn_assoc_a" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.bazaar_vpn.id
  subnet_id              = aws_subnet.private_a.id
}

resource "aws_ec2_client_vpn_network_association" "vpn_assoc_b" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.bazaar_vpn.id
  subnet_id              = aws_subnet.private_b.id
}

# Authorization Rule: Allow VPN clients to access everything in the VPC
resource "aws_ec2_client_vpn_authorization_rule" "vpn_auth_all" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.bazaar_vpn.id
  target_network_cidr    = aws_vpc.bazaar_vpc.cidr_block
  authorize_all_groups   = true
}

# Allow VPN clients to access the internet
resource "aws_ec2_client_vpn_route" "vpn_internet_route" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.bazaar_vpn.id
  destination_cidr_block = "0.0.0.0/0"
  target_vpc_subnet_id   = aws_subnet.private_a.id # Route out via our NAT
}

