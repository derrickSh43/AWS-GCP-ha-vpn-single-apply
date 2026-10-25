# Providers

terraform {
  required_version = ">= 1.11, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.28.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13.0"
    }
  }
}
provider "aws" {
  region = var.aws_region
}
provider "google" {
  project = var.project_id
  region  = var.region

  impersonate_service_account = var.gcp_deployment_service_account
}
provider "vault" {
  skip_child_token = true
}

# Inputs

variable "project_id" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "region" {
  type    = string
  default = "us-central1"
}


variable "vault_mount" {
  type    = string
  default = "vpn"
}

variable "vault_prefix" {
  type    = string
  default = "aws-gcp-vpn"
}

variable "aws_subnet_cidr" {
  type    = string
  default = "10.230.1.0/24"
}

variable "gcp_subnet_cidr" {
  type    = string
  default = "10.240.1.0/24"
}


variable "aws_deployment_role_name" {
  description = "Deployment must run as an STS session for this IAM role."
  type        = string
  default     = "aws-gcp-vpn-deployer"
}
variable "gcp_deployment_service_account" {
  description = "Service account to impersonate using short-lived OAuth credentials; no service-account key file."
  type        = string
  validation {
    condition     = can(regex("@[a-z0-9-]+\\.iam\\.gserviceaccount\\.com$", var.gcp_deployment_service_account))
    error_message = "A non-empty GCP service-account email is required; user-credential fallback is not allowed."
  }
}

variable "flow_log_permissions_boundary_arn" {
  description = "IAM permission ceiling created by the identity bootstrap for the flow-log delivery role."
  type        = string
}

# Gateways and VPN connections

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

# Subnets and routing

resource "aws_subnet" "workloads" {
  vpc_id                  = aws_vpc.aws_side.id
  cidr_block              = var.aws_subnet_cidr
  map_public_ip_on_launch = false
  tags                    = { Name = "vpn-workloads" }
}
resource "aws_route_table" "workloads" {
  vpc_id = aws_vpc.aws_side.id
  tags   = { Name = "vpn-workloads" }
}
resource "aws_route_table_association" "workloads" {
  subnet_id      = aws_subnet.workloads.id
  route_table_id = aws_route_table.workloads.id
}
resource "aws_vpn_gateway_route_propagation" "workloads" {
  vpn_gateway_id = aws_vpn_gateway.vpn_gw.id
  route_table_id = aws_route_table.workloads.id
}
resource "google_compute_subnetwork" "workloads" {
  name                     = "vpn-workloads"
  region                   = var.region
  network                  = google_compute_network.vpc_network.id
  ip_cidr_range            = var.gcp_subnet_cidr
  private_ip_google_access = true
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
resource "google_compute_firewall" "aws_workloads" {
  name          = "allow-aws-workload-icmp"
  network       = google_compute_network.vpc_network.name
  direction     = "INGRESS"
  source_ranges = [aws_vpc.aws_side.cidr_block]
  target_tags   = ["vpn-access"]
  allow { protocol = "icmp" }
}

# GCP tunnels and BGP

locals {
  tunnels = {
    tunnel0 = { interface = 0, peer_interface = 0, cidr = "169.254.145.128/30" }
    tunnel1 = { interface = 0, peer_interface = 1, cidr = "169.254.145.132/30" }
    tunnel2 = { interface = 1, peer_interface = 2, cidr = "169.254.145.136/30" }
    tunnel3 = { interface = 1, peer_interface = 3, cidr = "169.254.145.140/30" }
  }
}
data "vault_kv_secret_v2" "tunnel" {
  for_each = local.tunnels
  mount    = var.vault_mount
  name     = "${var.vault_prefix}/${each.key}"
}
resource "google_compute_vpn_tunnel" "tunnels" {
  for_each                        = local.tunnels
  name                            = each.key
  region                          = var.region
  vpn_gateway                     = google_compute_ha_vpn_gateway.ha_gateway.id
  vpn_gateway_interface           = each.value.interface
  peer_external_gateway           = google_compute_external_vpn_gateway.aws_gateway.id
  peer_external_gateway_interface = each.value.peer_interface
  shared_secret                   = data.vault_kv_secret_v2.tunnel[each.key].data["psk"]
  router                          = google_compute_router.router.name
  ike_version                     = 2
}
resource "google_compute_router_interface" "tunnels" {
  for_each   = local.tunnels
  name       = "router-interface-${each.key}"
  router     = google_compute_router.router.name
  region     = var.region
  ip_range   = "${cidrhost(each.value.cidr, 2)}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnels[each.key].name
}
resource "google_compute_router_peer" "tunnels" {
  for_each                  = local.tunnels
  name                      = "router-peer-${each.key}"
  router                    = google_compute_router.router.name
  region                    = var.region
  peer_ip_address           = cidrhost(each.value.cidr, 1)
  peer_asn                  = aws_vpn_gateway.vpn_gw.amazon_side_asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.tunnels[each.key].name

}

# Flow logs

resource "aws_default_security_group" "restricted" {
  vpc_id  = aws_vpc.aws_side.id
  ingress = []
  egress  = []
  tags    = { Name = "vpn-unused-default-deny" }
}
resource "aws_cloudwatch_log_group" "flow" {
  #checkov:skip=CKV_AWS_158:Lab flow metadata uses CloudWatch service-side encryption; deploy a customer-managed KMS key for production requirements.
  name_prefix       = "/aws/vpc/aws-gcp-vpn-"
  retention_in_days = 365
}
resource "aws_iam_role" "flow" {
  name_prefix          = "aws-gcp-vpn-flow-"
  permissions_boundary = var.flow_log_permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*" }
      }
    }]
  })
}
data "aws_caller_identity" "current" {}
resource "aws_iam_role_policy" "flow" {
  name = "write-vpc-flow-logs"
  role = aws_iam_role.flow.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.flow.arn}:*"
    }]
  })
}
resource "aws_flow_log" "workloads" {
  iam_role_arn    = aws_iam_role.flow.arn
  log_destination = aws_cloudwatch_log_group.flow.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.aws_side.id
  depends_on      = [aws_iam_role_policy.flow]
}

# Tunnel logs

resource "aws_kms_key" "vpn_logs" {
  description             = "Encrypt AWS to GCP VPN tunnel diagnostics"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountKeyAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CloudWatchTunnelLogEncryption"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }
        Action    = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vendedlogs/vpn/aws-gcp-*"
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "vpn_logs" {
  name          = "alias/aws-gcp-vpn-tunnel-logs"
  target_key_id = aws_kms_key.vpn_logs.key_id
}

resource "aws_cloudwatch_log_group" "vpn_tunnel" {
  for_each          = local.tunnels
  name              = "/aws/vendedlogs/vpn/aws-gcp-${each.key}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.vpn_logs.arn
}

resource "aws_cloudwatch_log_resource_policy" "vpn_delivery" {
  policy_name = "aws-gcp-vpn-tunnel-delivery"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = [for group in aws_cloudwatch_log_group.vpn_tunnel : "${group.arn}:*"]
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*" }
      }
    }]
  })
}

# HA VPN emits IKE/IPsec diagnostic logs to Cloud Logging automatically.
# This is separate from the subnet flow logs.
output "gcp_tunnel_log_filter" {
  value = "resource.type=\"vpn_gateway\" AND (${join(" OR ", [for tunnel in google_compute_vpn_tunnel.tunnels : "labels.tunnel_id=\"${tunnel.tunnel_id}\""])})"
}

output "aws_tunnel_log_groups" {
  value = { for key, group in aws_cloudwatch_log_group.vpn_tunnel : key => group.name }
}

# Alerts

variable "aws_alarm_action_arns" {
  type    = list(string)
  default = []
}
variable "gcp_notification_channels" {
  type    = list(string)
  default = []
}
locals {
  aws_tunnel_endpoints = {
    tunnel0 = { vpn = aws_vpn_connection.gcp_interface_1.id, ip = aws_vpn_connection.gcp_interface_1.tunnel1_address }
    tunnel1 = { vpn = aws_vpn_connection.gcp_interface_1.id, ip = aws_vpn_connection.gcp_interface_1.tunnel2_address }
    tunnel2 = { vpn = aws_vpn_connection.gcp_interface_2.id, ip = aws_vpn_connection.gcp_interface_2.tunnel1_address }
    tunnel3 = { vpn = aws_vpn_connection.gcp_interface_2.id, ip = aws_vpn_connection.gcp_interface_2.tunnel2_address }
  }
}
resource "aws_cloudwatch_metric_alarm" "tunnel" {
  for_each            = local.aws_tunnel_endpoints
  alarm_name          = "aws-gcp-${each.key}-down"
  alarm_description   = "VPN tunnel down or telemetry absent for two minutes"
  namespace           = "AWS/VPN"
  metric_name         = "TunnelState"
  dimensions          = { VpnId = each.value.vpn, TunnelIpAddress = each.value.ip }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = var.aws_alarm_action_arns
  ok_actions          = var.aws_alarm_action_arns
}
resource "google_monitoring_alert_policy" "tunnel" {
  display_name          = "AWS HA VPN tunnel unavailable"
  combiner              = "OR"
  notification_channels = var.gcp_notification_channels
  conditions {
    display_name = "Established tunnels below one per tunnel"
    condition_threshold {
      filter          = "resource.type = \"vpn_gateway\" AND resource.labels.project_id = \"${var.project_id}\" AND metric.labels.gateway_name = \"${google_compute_ha_vpn_gateway.ha_gateway.name}\" AND metric.type = \"vpn.googleapis.com/tunnel_established\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "120s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MIN"
      }
      trigger { count = 1 }
    }
  }
}

output "aws_vpn_ids" {
  value = [aws_vpn_connection.gcp_interface_1.id, aws_vpn_connection.gcp_interface_2.id]
}
