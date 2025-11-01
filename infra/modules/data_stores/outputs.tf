output "db_address" {
  value = aws_db_instance.db.address
}
output "db_port" {
  value = aws_db_instance.db.port
}
output "db_username" {
  value = aws_db_instance.db.username
}
output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}

output "redis_address" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}
output "redis_port" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].port
}

output "msk_cluster_arn" {
  value = aws_msk_cluster.kafka.arn
}
output "msk_bootstrap_brokers_tls" {
  value     = aws_msk_cluster.kafka.bootstrap_brokers_tls
  sensitive = true
}
output "msk_bootstrap_brokers_iam" {
  value     = aws_msk_cluster.kafka.bootstrap_brokers_sasl_iam
  sensitive = true
}

