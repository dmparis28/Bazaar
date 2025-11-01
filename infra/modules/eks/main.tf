# --- MODULE: VPN ---
# Our secure developer "airlock" into the VPC.

resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_key.private_key_pem
  algorithm       = "RSA"

  subject {
    common_name  = "Bazaar VPN CA"
    organization = "Bazaar Inc."
  }

  is_ca_certificate     = true
  validity_period_hours = 8760 # 1 year
  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "server_auth",
    "client_auth",
  ]
}

resource "aws_acm_certificate" "server_cert" {
  private_key       = tls_private_key.ca_key.private_key_pem # Re-use CA key for simplicity
  certificate_body  = tls_self_signed_cert.ca_cert.cert_pem  # Re-use CA cert for simplicity
  certificate_chain = tls_self_signed_cert.ca_cert.cert_pem
}

resource "aws_acm_certificate" "client_cert" {
  private_key       = tls_private_key.ca_key.private_key_pem
  certificate_body  = tls_self_signed_cert.ca_cert.cert_pem
  certificate_chain = tls_self_signed_cert.ca_cert.cert_pem
}

resource "aws_ec2_client_vpn_endpoint" "this" {
  description            = "${var.name_prefix}-client-vpn"
  server_certificate_arn = aws_acm_certificate.server_cert.arn
  client_cidr_block      = "192.168.0.0/22" # Our VPN client IP range

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client_cert.arn
  }

  connection_log_options {
    enabled = false # Can be enabled for production
  }

  # Use split-tunnel to only route VPC traffic
  split_tunnel = true

  tags = {
    Name = "${var.name_prefix}-client-vpn"
  }
}

resource "aws_ec2_client_vpn_network_association" "a" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = var.private_subnet_ids[0]
}

resource "aws_ec2_client_vpn_network_association" "b" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = var.private_subnet_ids[1]
}

# --- *** FIX 1: REMOVED THE 0.0.0.0/0 ROUTE *** ---
# We are in split-tunnel mode, so we should NOT route all internet traffic.
# This resource has been deleted.

# --- *** FIX 2: THIS IS NOW THE *ONLY* ROUTE *** ---
resource "aws_ec2_client_vpn_route" "vpn_local_vpc_route" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  destination_cidr_block = var.vpc_cidr # This is our "10.0.0.0/16"
  target_vpc_subnet_id   = var.private_subnet_ids[0] # Route to any subnet
  description            = "Route for local VPC traffic"

  # --- *** FIX 3: DEPEND ON *BOTH* SUBNET ASSOCIATIONS *** ---
  depends_on = [
    aws_ec2_client_vpn_network_association.a,
    aws_ec2_client_vpn_network_association.b
  ]
}
# --- *** END OF FIXES *** ---

# --- *** FIX 4: AUTHORIZE *ONLY* THE VPC CIDR *** ---
resource "aws_ec2_client_vpn_authorization_rule" "vpn_auth_vpc" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = var.vpc_cidr # Was 0.0.0.0/0
  authorize_all_groups   = true
  description            = "Allow all users to access the VPC"
}

