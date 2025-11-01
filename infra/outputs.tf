# This file passes through the outputs from our modules
# to the root level so we can see them.

# --- 1. DATABASE (RDS) ---
output "db_address" {
  value = module.data_stores.db_address
}
output "db_port" {
  value = module.data_stores.db_port
}
output "db_username" {
  value = module.data_stores.db_username
}
output "db_password" {
  value     = module.data_stores.db_password
  sensitive = true
}

# --- 2. CACHE (Redis) ---
output "redis_address" {
  value = module.data_stores.redis_address
}
output "redis_port" {
  value = module.data_stores.redis_port
}

# --- 3. KAFKA (MSK) ---
output "msk_cluster_arn" {
  value = module.data_stores.msk_cluster_arn
}
output "msk_bootstrap_brokers_tls" {
  value     = module.data_stores.msk_bootstrap_brokers_tls
  sensitive = true
}
output "msk_bootstrap_brokers_iam" {
  value     = module.data_stores.msk_bootstrap_brokers_iam
  sensitive = true
}

# --- 4. KUBERNETES (EKS) ---
output "eks_cluster_name" {
  value = module.eks.cluster_name
}
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

# --- 5. VPN CONFIG ---
output "vpn_client_config" {
  value     = module.vpn.vpn_client_config
  sensitive = true
}

