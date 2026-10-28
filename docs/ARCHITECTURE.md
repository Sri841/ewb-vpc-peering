# Architecture and why each rule exists

| Resource | CIDR / IP | Purpose |
|---|---|---|
| ewb-vpc-a | 10.10.0.0/16 | Hosts bastion + App-A |
| ewb-a-public | 10.10.1.0/24 | Bastion 10.10.1.10 (+public IPv4); route 0.0.0.0/0 -> IGW |
| ewb-a-private | 10.10.2.0/24 | App-A 10.10.2.10, no public IP, no internet route |
| ewb-vpc-b | 10.20.0.0/16 | Hosts App-B, no internet gateway |
| ewb-b-private | 10.20.1.0/24 | App-B 10.20.1.10, no public IP |

## Routes
| Route table | Destination | Target | Why |
|---|---|---|---|
| ewb-rt-a-public | 0.0.0.0/0 | igw | Bastion internet access |
| ewb-rt-a-public | 10.20.0.0/16 | pcx | Bastion opens SSH to App-B (ProxyJump); more specific than the default route |
| ewb-rt-a-private | 10.20.0.0/16 | pcx | Forward path App-A -> VPC B |
| ewb-rt-b-private | 10.10.0.0/16 | pcx | Return path - replies need a route back |

## Security groups (inbound)
| SG | Rule | Source |
|---|---|---|
| bastion | TCP 22 | my public IP /32 |
| app-a | TCP 22 | 10.10.1.10/32 |
| app-a | ICMP echo request | 10.20.1.10/32 |
| app-a (extra) | TCP 8080 | 10.10.1.10/32 (SSH tunnel) |
| app-b | TCP 22 | 10.10.1.10/32 (App-B sees the bastion's private IP) |
| app-b | ICMP echo request | 10.10.2.10/32 |
| app-b (extra) | TCP 9000 | 10.10.2.10/32 |

## Viva answers (workbook page 12)
1. **Why a return route?** Peering is a link, not routing. Replies from App-B to 10.10.x.x need a route in VPC B's table or they are dropped.
2. **Why is the App-B SSH source the bastion private IP?** ProxyJump opens a new SSH connection from the bastion to App-B; App-B sees the bastion's private source address, not your laptop's.
3. **Why does Active peering not guarantee ping?** Active only means the link exists. Routes on both sides, security groups (and NACLs) still decide whether packets pass.
4. **Can VPC B use VPC A's IGW over peering?** No. Peering does not provide edge-to-edge routing; traffic via the peer must be destined for the peer VPC's CIDR. VPC B stays isolated from the internet.
5. **Transitivity:** A-B plus A-C does not give B-C connectivity.
