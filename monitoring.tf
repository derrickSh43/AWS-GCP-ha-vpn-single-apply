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
