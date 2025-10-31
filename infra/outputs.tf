# This file exports important values from our infrastructure
# so we can use them in our application and K8s configs.

# ---
# 1. DATABASE (RDS)
# ---
output "db_address" {
  value       = aws_db_instance.bazaar_db.address
  description = "The address of the RDS database"
}
output "db_port" {
  value       = aws_db_instance.bazaar_db.port
  description = "The port of the RDS database"
}
output "db_username" {
  value       = aws_db_instance.bazaar_db.username
  description = "The username for the RDS database"
}
output "db_password" {
  value       = random_password.db_password.result
  description = "The password for the RDS database"
  sensitive   = true
}

# ---
# 2. CACHE (Redis)
# ---
output "redis_address" {
  value       = aws_elasticache_cluster.bazaar_redis.cache_nodes[0].address
  description = "The address of the Redis cache"
}
output "redis_port" {
  value       = aws_elasticache_cluster.bazaar_redis.cache_nodes[0].port
  description = "The port of the Redis cache"
}

# ---
# 3. KAFKA (MSK)
# ---
output "msk_cluster_arn" {
  value       = aws_msk_cluster.bazaar_kafka.arn
  description = "The ARN of the MSK (Kafka) cluster"
}
output "msk_bootstrap_brokers_tls" {
  value       = aws_msk_cluster.bazaar_kafka.bootstrap_brokers_tls
  description = "The bootstrap servers for Kafka (TLS)"
  sensitive   = true
}
output "msk_bootstrap_brokers_iam" {
  value       = aws_msk_cluster.bazaar_kafka.bootstrap_brokers_sasl_iam
  description = "The bootstrap servers for Kafka (IAM Auth)"
  sensitive   = true
}

# ---
# 4. KUBERNETES (EKS)
# ---
output "eks_cluster_name" {
  value       = aws_eks_cluster.bazaar_cluster.name
  description = "The name of the EKS cluster"
}
output "eks_cluster_endpoint" {
  value       = aws_eks_cluster.bazaar_cluster.endpoint
  description = "The private endpoint for the EKS cluster"
}

# ---
# 5. VPN CONFIG
# ---
output "vpn_client_config" {
  value = aws_ec2_client_vpn_endpoint.bazaar_vpn.dns_name != "" ? templatefile("vpn_config.ovpn", {
    vpn_dns_name = aws_ec2_client_vpn_endpoint.bazaar_vpn.dns_name
    # Point to the TLS provider resources, not the ACM ones
    server_cert  = tls_self_signed_cert.vpn_ca_cert.cert_pem
    client_cert  = tls_locally_signed_cert.vpn_client_cert.cert_pem
    client_key   = tls_private_key.vpn_client_key.private_key_pem
  }) : "VPN endpoint is still creating, please 'terraform apply' again in a few minutes."
  description = "The .ovpn file content for the Client VPN"
  sensitive   = true
}

