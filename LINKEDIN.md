Built and tested an AWS-Google Cloud VPN lab with Terraform: two AWS VPN connections, four IKEv2/IPsec tunnels across both GCP HA VPN interfaces, and dynamic BGP routing.

The updated version adds private workload subnets, AWS route propagation, scoped test traffic, four independent Vault keys, encrypted remote state, flow logs, tunnel monitoring, and automated formatting, validation, linting and security checks.

For the failover test, I withdrew both BGP peers on one GCP interface, verified private-IP connectivity in both directions through the surviving pair, then repeated the test on the opposite interface. All four peers were restored afterward.

The short demo shows the actual cloud console beside the actual terminal, including BGP session state and private-VM ping results. Waiting periods are shortened. It demonstrates observed route failover; it does not claim zero packet loss or measured production availability.
