# AWS ↔ GCP HA VPN

A personal Terraform project connecting AWS and Google Cloud through four IPsec tunnels with BGP routing, Vault-managed tunnel keys, temporary deployment credentials, logging, and alerts.

```mermaid
flowchart LR
    AWS[AWS VPC] --- VGW[Virtual Private Gateway]
    VGW <-->|Four IPsec tunnels| HA[GCP HA VPN]
    HA --- CR[Cloud Router · BGP]
    CR --- GCP[GCP VPC]
```

## A problem I solved

IPsec was up, but BGP would not establish because both ends used the same inside-tunnel IP. I corrected the Terraform addressing: AWS uses the first usable host in each `/30`, and GCP uses the second.

## Demo

[![Watch the failover demo](demo/failover-preview.png)](demo/aws-gcp-console-terminal-failover.mp4)

[Watch the one-minute demo](demo/aws-gcp-console-terminal-failover.mp4) · [Deploy it](SETUP.md)
