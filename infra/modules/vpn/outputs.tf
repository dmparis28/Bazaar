output "vpn_client_config" {
  description = "The .ovpn file content for the Client VPN"
  sensitive   = true
  value = aws_ec2_client_vpn_endpoint.vpn.dns_name != "" ? templatefile("${path.root}/vpn_config.ovpn", {
    vpn_dns_name = aws_ec2_client_vpn_endpoint.vpn.dns_name
    server_cert  = tls_self_signed_cert.vpn_ca_cert.cert_pem
    client_cert  = tls_locally_signed_cert.vpn_client_cert.cert_pem
    client_key   = tls_private_key.vpn_client_key.private_key_pem
  }) : "VPN endpoint is still creating, please 'terraform apply' again in a few minutes."
}

