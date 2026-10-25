# Connectivity and failover acceptance

After apply, allow several minutes for IPsec/BGP and VM initialization.

1. AWS: describe both VPN connections and verify all four VgwTelemetry statuses are UP. GCP: describe each tunnel, check ESTABLISHED and Cloud Router get-status shows four established BGP peers.
2. Inspect the AWS workload route table: the GCP /24 must be propagated via the VGW. Inspect Cloud Router learned routes: AWS VPC 10.230.0.0/16 must be present. Verify subnet association and absence of conflicting routes.
3. Retrieve AWS test VM console output (`aws ec2 get-console-output --instance-id <output> --latest --query Output --output text`) and GCP serial output (`gcloud compute instances get-serial-port-output vpn-test-gcp --zone <zone> --project <project>`). Both must show recent VPN_TEST_PASS and replies from the correct peer. Boot loops last approximately 30-50 minutes; GCP serial logging requires guest startup script execution. If ping is absent, use a prebuilt image with iputils; these hosts have no internet NAT.
4. Capture baseline success/loss and timestamps while the loops run. Apply disabled_bgp_peers=["tunnel0"], then ["tunnel0","tunnel1"] to withdraw all GCP BGP sessions on interface 0. Review each saved plan: only peer enable flags should change. Verify surviving BGP sessions, learned routes, and resumed ping replies. Record outage duration and packet loss; do not claim zero interruption. This is BGP failover, not an IPsec transport failure simulation.
5. Restore disabled_bgp_peers=[] and verify four sessions and bidirectional connectivity recover. Observe GCP/AWS alarms separately: disabling BGP alone need not set IPsec TunnelState down. Full tunnel-failure alarm testing is a separate controlled outage.
6. Verify actual negotiated crypto from cloud tunnel diagnostics. Validate alerts with real configured notification targets. Empty destination lists create policies but send no notifications.
7. Record evidence and destroy the test infrastructure when finished. Keep Vault available through destroy.

## Commands

```powershell
terraform output aws_vpn_ids
aws ec2 describe-vpn-connections --region us-east-1 --query 'VpnConnections[].{Id:VpnConnectionId,Telemetry:VgwTelemetry}'
gcloud compute routers get-status vpn-router --region us-central1 --project YOUR_PROJECT
Set-Content -LiteralPath failover.local.tfvars -Value 'disabled_bgp_peers = ["tunnel0"]'
terraform plan '-var-file=failover.local.tfvars' '-out=failover.tfplan'
terraform apply failover.tfplan
Set-Content -LiteralPath failover.local.tfvars -Value 'disabled_bgp_peers = []'
terraform plan '-var-file=failover.local.tfvars' '-out=restore.tfplan'
terraform apply restore.tfplan
```

Console output and plans can contain sensitive diagnostics: keep them out of public artifacts. Test scripts run a bounded ICMP loop with ten seconds between attempts; this supports coarse recovery timing, not subsecond convergence measurement.

Guest scripts require LF line endings. The repository .gitattributes preserves them; Windows CRLF shebangs fail to execute on Linux.
