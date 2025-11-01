# --- MODULE: VPN ---
# Secure developer access via Client VPN

# 1. Create the Private Key for our new CA
resource "tls_private_key" "vpn_ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 2. Create the self-signed Root Certificate for our CA
resource "tls_self_signed_cert" "vpn_ca_cert" {
  private_key_pem = tls_private_key.vpn_ca_key.private_key_pem

  subject {
    common_name  = "${var.name_prefix}.vpn.ca"
    organization = "${var.name_prefix} Inc."
  }

  validity_period_hours = 8760 # 1 year
  is_ca_certificate     = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
  ]
}

# 3. Create a Private Key for the VPN Server
resource "tls_private_key" "vpn_server_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 4. Create a Certificate Signing Request (CSR) for the server
resource "tls_cert_request" "vpn_server_csr" {
  private_key_pem = tls_private_key.vpn_server_key.private_key_pem

  subject {
    common_name  = "server.vpn.${var.name_prefix}.internal"
    organization = "${var.name_prefix} Inc."
  }
}

# 5. Sign the server's CSR with our CA key to create its certificate
resource "tls_locally_signed_cert" "vpn_server_cert" {
  cert_request_pem   = tls_cert_request.vpn_server_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.vpn_ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.vpn_ca_cert.cert_pem

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# 6. Create a Private Key for the VPN Client
resource "tls_private_key" "vpn_client_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 7. Create a CSR for the client
resource "tls_cert_request" "vpn_client_csr" {
  private_key_pem = tls_private_key.vpn_client_key.private_key_pem

  subject {
    common_name  = "client.vpn.${var.name_prefix}.internal"
    organization = "${var.name_prefix} Inc."
  }
}

# 8. Sign the client's CSR with our CA key to create its certificate
resource "tls_locally_signed_cert" "vpn_client_cert" {
  cert_request_pem   = tls_cert_request.vpn_client_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.vpn_ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.vpn_ca_cert.cert_pem

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# 9. Now, IMPORT these generated certs into AWS Certificate Manager (ACM)
resource "aws_acm_certificate" "vpn_server_cert_import" {
  private_key       = tls_private_key.vpn_server_key.private_key_pem
  certificate_body  = tls_locally_signed_cert.vpn_server_cert.cert_pem
  certificate_chain = tls_self_signed_cert.vpn_ca_cert.cert_pem

  tags = {
    Name = "${var.name_prefix}-vpn-server-cert"
  }
}

resource "aws_acm_certificate" "vpn_client_cert_import" {
  private_key       = tls_private_key.vpn_client_key.private_key_pem
  certificate_body  = tls_locally_signed_cert.vpn_client_cert.cert_pem
  certificate_chain = tls_self_signed_cert.vpn_ca_cert.cert_pem

  tags = {
    Name = "${var.name_prefix}-vpn-client-cert"
  }
}

# The VPN Endpoint
resource "aws_ec2_client_vpn_endpoint" "vpn" {
  description            = "${var.name_prefix} Client VPN"
  server_certificate_arn = aws_acm_certificate.vpn_server_cert_import.arn
  client_cidr_block      = "192.168.0.0/22" # CIDR for our laptops

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.vpn_client_cert_import.arn
  }

  connection_log_options {
    enabled = false
  }

  dns_servers        = ["10.0.0.2"] # VPC's internal DNS resolver
  transport_protocol = "udp"
}

# Associate VPN with our private network
resource "aws_ec2_client_vpn_network_association" "vpn_assoc_a" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  subnet_id              = var.private_subnet_ids[0]
}

resource "aws_ec2_client_vpn_network_association" "vpn_assoc_b" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  subnet_id              = var.private_subnet_ids[1]
}

# Authorization Rule: Allow VPN clients to access everything in the VPC
resource "aws_ec2_client_vpn_authorization_rule" "vpn_auth_all" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  target_network_cidr    = var.vpc_cidr_block
  authorize_all_groups   = true
}

# Allow VPN clients to access the internet
resource "aws_ec2_client_vpn_route" "vpn_internet_route" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  destination_cidr_block = "0.0.0.0/0"
  target_vpc_subnet_id   = var.private_subnet_ids[0] # Route out via NAT A
  
  depends_on = [
    aws_ec2_client_vpn_network_association.vpn_assoc_a,
    aws_ec2_client_vpn_network_association.vpn_assoc_b
  ]
}

