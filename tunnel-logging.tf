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
# This is separate from the subnet flow logs in network.tf.
output "gcp_tunnel_log_filter" {
  value = "resource.type=\"vpn_gateway\" AND (${join(" OR ", [for tunnel in google_compute_vpn_tunnel.tunnels : "labels.tunnel_id=\"${tunnel.tunnel_id}\""])})"
}

output "aws_tunnel_log_groups" {
  value = { for key, group in aws_cloudwatch_log_group.vpn_tunnel : key => group.name }
}
