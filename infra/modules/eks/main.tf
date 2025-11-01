# --- MODULE: EKS ---
# Our secure, private compute fabric.

resource "aws_security_group" "cluster_sg" {
  name   = "${var.name_prefix}-eks-cluster-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow cluster to cluster"
  }

  # --- *** THE *NEW* FIX IS HERE *** ---
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.0.0/22"] # Allow traffic from Client VPN
    description = "Allow all traffic from Client VPN"
  }
  # --- *** END OF NEW FIX *** ---

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-eks-cluster-sg"
  }
}

resource "aws_security_group" "node_sg" {
  name   = "${var.name_prefix}-eks-node-sg"
  vpc_id = var.vpc_id

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
    security_groups = [aws_security_group.cluster_sg.id]
    description = "Allow cluster control plane to nodes"
  }

  # --- *** THE FIRST FIX (STILL NEEDED) *** ---
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.0.0/22"] # Allow traffic from Client VPN
    description = "Allow all traffic from Client VPN"
  }
  # --- *** END OF FIRST FIX *** ---

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-eks-node-sg"
  }
}

resource "aws_iam_role" "cluster_role" {
  name = "${var.name_prefix}-eks-cluster-role"

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

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}

resource "aws_iam_role" "node_role" {
  name = "${var.name_prefix}-eks-node-role"

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

resource "aws_iam_role_policy_attachment" "node_policy_1" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_role.name
}

resource "aws_iam_role_policy_attachment" "node_policy_2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_role.name
}

resource "aws_iam_role_policy_attachment" "node_policy_3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_role.name
}

resource "aws_kms_key" "secrets_key" {
  description             = "KMS key for encrypting ${var.name_prefix} EKS secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_eks_cluster" "this" {
  name     = "${var.name_prefix}-cluster"
  role_arn = aws_iam_role.cluster_role.arn
  version  = var.cluster_version

  vpc_config {
    security_group_ids = [aws_security_group.cluster_sg.id, aws_security_group.node_sg.id]
    subnet_ids = concat(
      var.private_subnet_ids,
      var.cde_subnet_ids
    )
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.secrets_key.arn
    }
    resources = ["secrets"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
  ]
}

resource "aws_eks_node_group" "general_nodes" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "general-nodes"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = ["t3.medium"]

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
    aws_iam_role_policy_attachment.node_policy_1,
    aws_iam_role_policy_attachment.node_policy_2,
    aws_iam_role_policy_attachment.node_policy_3,
  ]
}

resource "aws_eks_node_group" "cde_nodes" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "cde-nodes"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = var.cde_subnet_ids
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  taint {
    key    = "cde"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "node-type" = "cde-secure-nodes"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy_1,
    aws_iam_role_policy_attachment.node_policy_2,
    aws_iam_role_policy_attachment.node_policy_3,
  ]
}

