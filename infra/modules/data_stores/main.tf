# --- MODULE: DATA STORES ---
# Defines our stateful services: RDS, Redis, and MSK.

# --- PostgreSQL Database (RDS) ---
resource "aws_security_group" "rds_sg" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Allow internal traffic to RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.name_prefix}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.name_prefix} RDS Subnet Group"
  }
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&()*+,-.:;<=>?_[]^`{|}~"
}

resource "aws_db_instance" "db" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  identifier             = "${var.name_prefix}-db"
  username               = "${var.name_prefix}admin"
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  multi_az               = true
  storage_encrypted      = true
}

# --- Redis Cache (ElastiCache) ---
resource "aws_security_group" "redis_sg" {
  name        = "${var.name_prefix}-redis-sg"
  description = "Allow internal traffic to Redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${var.name_prefix}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id         = "${var.name_prefix}-redis"
  engine             = "redis"
  node_type          = "cache.t3.micro"
  num_cache_nodes    = 1
  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids = [aws_security_group.redis_sg.id]
}

# --- Apache Kafka (MSK) ---
resource "aws_security_group" "msk_sg" {
  name        = "${var.name_prefix}-msk-sg"
  description = "Allow internal traffic to MSK/Kafka"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2181 # Zookeeper
    to_port         = 2181
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
  }
  ingress {
    from_port       = 9092 # Plaintext
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
  }
  ingress {
    from_port       = 9094 # TLS
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
  }
  ingress {
    from_port       = 9098 # IAM
    to_port         = 9098
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_kms_key" "msk_key" {
  description             = "KMS key for encrypting ${var.name_prefix} MSK"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}


resource "aws_msk_cluster" "kafka" {
  cluster_name           = "${var.name_prefix}-kafka-cluster"
  kafka_version          = "3.7.x"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type = "kafka.t3.small"
    client_subnets = var.private_subnet_ids
    security_groups = [aws_security_group.msk_sg.id]
    storage_info {
      ebs_storage_info {
        volume_size = 10
      }
    }
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.msk_key.arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }
  
  client_authentication {
    sasl {
      iam = true
    }
  }
  
  tags = {
    Name = "${var.name_prefix}-kafka-cluster"
  }
}

