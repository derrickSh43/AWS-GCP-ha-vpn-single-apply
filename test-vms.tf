variable "enable_test_vms" {
  type    = bool
  default = false
}
data "aws_ssm_parameter" "test_ami" {
  count = var.enable_test_vms ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
resource "aws_security_group" "test" {
  count       = var.enable_test_vms ? 1 : 0
  name_prefix = "vpn-test-"
  description = "Private ICMP connectivity test"
  vpc_id      = aws_vpc.aws_side.id
  ingress {
    description = "ICMP from GCP test subnet"
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = [var.gcp_subnet_cidr]
  }
  egress {
    description = "ICMP to GCP test subnet"
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = [var.gcp_subnet_cidr]
  }
}
resource "aws_instance" "test" {
  #checkov:skip=CKV2_AWS_41:Disposable ICMP-only test VM intentionally has no IAM role or AWS API permissions.
  count                       = var.enable_test_vms ? 1 : 0
  ami                         = data.aws_ssm_parameter.test_ami[0].value
  instance_type               = "t3.micro"
  monitoring                  = true
  ebs_optimized               = true
  subnet_id                   = aws_subnet.workloads.id
  private_ip                  = cidrhost(var.aws_subnet_cidr, 10)
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.test[0].id]
  metadata_options {
    http_tokens = "required"
  }
  root_block_device {
    encrypted   = true
    volume_size = 8
  }
  user_data  = <<-SCRIPT
    #!/bin/bash
    exec > >(tee /dev/console) 2>&1
    for attempt in $(seq 1 180); do
      echo "VPN_TEST timestamp=$(date -u +%FT%TZ) attempt=$attempt peer=${cidrhost(var.gcp_subnet_cidr, 10)}"
      ping -n -c 3 -W 2 ${cidrhost(var.gcp_subnet_cidr, 10)} && echo VPN_TEST_PASS || echo VPN_TEST_RETRY
      sleep 10
    done
  SCRIPT
  tags       = { Name = "vpn-test-aws" }
  depends_on = [aws_vpn_gateway_route_propagation.workloads]
}
resource "google_compute_instance" "test" {
  #checkov:skip=CKV_GCP_38:Disposable test disk uses Google-managed encryption; customer-supplied keys are not required for this lab.
  count        = var.enable_test_vms ? 1 : 0
  name         = "vpn-test-gcp"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["vpn-access"]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.workloads.id
    network_ip = cidrhost(var.gcp_subnet_cidr, 10)
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  metadata                = { block-project-ssh-keys = "true" }
  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    exec > >(tee /dev/ttyS0) 2>&1
    for attempt in $(seq 1 180); do
      echo "VPN_TEST timestamp=$(date -u +%FT%TZ) attempt=$attempt peer=${cidrhost(var.aws_subnet_cidr, 10)}"
      ping -n -c 3 -W 2 ${cidrhost(var.aws_subnet_cidr, 10)} && echo VPN_TEST_PASS || echo VPN_TEST_RETRY
      sleep 10
    done
  SCRIPT
}
output "aws_test_instance_id" {
  value = try(aws_instance.test[0].id, null)
}
output "gcp_test_instance_name" {
  value = try(google_compute_instance.test[0].name, null)
}
output "aws_vpn_ids" {
  value = [aws_vpn_connection.gcp_interface_1.id, aws_vpn_connection.gcp_interface_2.id]
}
