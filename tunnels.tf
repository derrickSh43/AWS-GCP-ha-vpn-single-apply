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
  enable                    = !contains(var.disabled_bgp_peers, each.key)
}
