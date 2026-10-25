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
  name          = "allow-aws-workload-tests"
  network       = google_compute_network.vpc_network.name
  direction     = "INGRESS"
  source_ranges = [aws_vpc.aws_side.cidr_block]
  target_tags   = ["vpn-access"]
  allow { protocol = "icmp" }
}
