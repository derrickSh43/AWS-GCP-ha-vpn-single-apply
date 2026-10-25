resource "aws_vpc" "aws_side" {
  cidr_block           = "10.230.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  lifecycle {
    precondition {
      condition     = can(regex(":assumed-role/${var.aws_deployment_role_name}/", data.aws_caller_identity.current.arn))
      error_message = "Use an AWS STS assumed-role session for the configured deployment role; IAM user credentials are not accepted for deployment."
    }
  }

  tags = {
    Name = "aws_main"
  }
}

resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id          = aws_vpc.aws_side.id
  amazon_side_asn = 64512

  tags = {
    Name = "main"
  }
}

resource "aws_customer_gateway" "tunnel" {
  bgp_asn = 65000
  ip_address = [
    for iface in google_compute_ha_vpn_gateway.ha_gateway.vpn_interfaces :
    iface.ip_address if iface.id == 0
  ][0]
  type = "ipsec.1"

  tags = {
    Name = "gcp-cgw-t1"
  }
}

resource "aws_customer_gateway" "tunnel2" {
  bgp_asn = 65000
  ip_address = [
    for iface in google_compute_ha_vpn_gateway.ha_gateway.vpn_interfaces :
    iface.ip_address if iface.id == 1
  ][0]
  type = "ipsec.1"

  tags = {
    Name = "gcp-cgw-t2"
  }
}

resource "aws_vpn_connection" "gcp_interface_1" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
  customer_gateway_id = aws_customer_gateway.tunnel.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr                  = "169.254.145.128/30"
  tunnel1_preshared_key                = data.vault_kv_secret_v2.tunnel["tunnel0"].data["psk"]
  tunnel1_ike_versions                 = ["ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [16]
  tunnel1_phase2_encryption_algorithms = ["AES256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers      = [16]

  tunnel2_inside_cidr                  = "169.254.145.132/30"
  tunnel2_preshared_key                = data.vault_kv_secret_v2.tunnel["tunnel1"].data["psk"]
  tunnel2_ike_versions                 = ["ikev2"]
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_dh_group_numbers      = [16]
  tunnel2_phase2_encryption_algorithms = ["AES256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_dh_group_numbers      = [16]

  depends_on = [aws_cloudwatch_log_resource_policy.vpn_delivery]

  tunnel1_log_options {
    cloudwatch_log_options {
      log_enabled       = true
      log_group_arn     = aws_cloudwatch_log_group.vpn_tunnel["tunnel0"].arn
      log_output_format = "json"
    }
  }

  tunnel2_log_options {
    cloudwatch_log_options {
      log_enabled       = true
      log_group_arn     = aws_cloudwatch_log_group.vpn_tunnel["tunnel1"].arn
      log_output_format = "json"
    }
  }

  tags = {
    Name = "aws-to-gcp-vpn-inf1"
  }
}

resource "aws_vpn_connection" "gcp_interface_2" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
  customer_gateway_id = aws_customer_gateway.tunnel2.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr                  = "169.254.145.136/30"
  tunnel1_preshared_key                = data.vault_kv_secret_v2.tunnel["tunnel2"].data["psk"]
  tunnel1_ike_versions                 = ["ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [16]
  tunnel1_phase2_encryption_algorithms = ["AES256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers      = [16]

  tunnel2_inside_cidr                  = "169.254.145.140/30"
  tunnel2_preshared_key                = data.vault_kv_secret_v2.tunnel["tunnel3"].data["psk"]
  tunnel2_ike_versions                 = ["ikev2"]
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_dh_group_numbers      = [16]
  tunnel2_phase2_encryption_algorithms = ["AES256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_dh_group_numbers      = [16]

  depends_on = [aws_cloudwatch_log_resource_policy.vpn_delivery]

  tunnel1_log_options {
    cloudwatch_log_options {
      log_enabled       = true
      log_group_arn     = aws_cloudwatch_log_group.vpn_tunnel["tunnel2"].arn
      log_output_format = "json"
    }
  }

  tunnel2_log_options {
    cloudwatch_log_options {
      log_enabled       = true
      log_group_arn     = aws_cloudwatch_log_group.vpn_tunnel["tunnel3"].arn
      log_output_format = "json"
    }
  }

  tags = {
    Name = "aws-to-gcp-vpn-inf2"
  }
}

resource "google_compute_network" "vpc_network" {
  name                    = "gcp-vpc-network"
  auto_create_subnetworks = false
}

resource "google_compute_ha_vpn_gateway" "ha_gateway" {
  name    = "ha-vpn-gateway"
  region  = var.region
  network = google_compute_network.vpc_network.id
}

resource "google_compute_external_vpn_gateway" "aws_gateway" {
  name            = "aws-external-gateway"
  redundancy_type = "FOUR_IPS_REDUNDANCY"

  interface {
    id         = 0
    ip_address = aws_vpn_connection.gcp_interface_1.tunnel1_address
  }

  interface {
    id         = 1
    ip_address = aws_vpn_connection.gcp_interface_1.tunnel2_address
  }

  interface {
    id         = 2
    ip_address = aws_vpn_connection.gcp_interface_2.tunnel1_address
  }

  interface {
    id         = 3
    ip_address = aws_vpn_connection.gcp_interface_2.tunnel2_address
  }
}

resource "google_compute_router" "router" {
  name    = "vpn-router"
  region  = var.region
  network = google_compute_network.vpc_network.id


  bgp {
    asn            = 65000
    advertise_mode = "CUSTOM"
    advertised_ip_ranges {
      range = google_compute_subnetwork.workloads.ip_cidr_range
    }
  }
}
