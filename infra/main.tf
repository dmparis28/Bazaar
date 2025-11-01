# --- BAZAAR INFRASTRUCTURE (MODULAR ROOT) ---
# This is our new root file. Its only job is to
# call our modules and wire them together.

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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---
# 1. NETWORKING (VPC)
# ---
module "vpc" {
  source     = "./modules/vpc"
  name_prefix = "bazaar"
  region     = var.region
}

# ---
# 2. KUBERNETES (EKS)
# ---
module "eks" {
  source                  = "./modules/eks"
  name_prefix             = "bazaar"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  cde_subnet_ids          = module.vpc.cde_subnet_ids
  cluster_version         = "1.30"
  
  depends_on = [module.vpc]
}

# ---
# 3. DATA STORES (Database, Cache, Kafka)
# ---
module "data_stores" {
  source                 = "./modules/data_stores"
  name_prefix            = "bazaar"
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id
  
  depends_on = [module.eks]
}

# ---
# 4. SECURE DEVELOPER ACCESS (Client VPN)
# ---
module "vpn" {
  source              = "./modules/vpn"
  name_prefix         = "bazaar"
  vpc_id              = module.vpc.vpc_id
  vpc_cidr_block      = module.vpc.vpc_cidr_block
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  depends_on = [module.vpc]
}

# ---
# 5. KUBERNETES PROVIDER
# This allows Terraform to talk to our new EKS cluster
# ---

data "aws_eks_cluster" "bazaar_cluster" {
  name = module.eks.cluster_name
  depends_on = [
    module.eks
  ]
}

data "aws_eks_cluster_auth" "bazaar_cluster" {
  name = module.eks.cluster_name
  depends_on = [
    module.eks
  ]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.bazaar_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.bazaar_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.bazaar_cluster.token
}

