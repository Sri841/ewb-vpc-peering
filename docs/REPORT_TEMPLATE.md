# AWS VPC Peering - Project Report
**Name:** ______  **Batch:** ______  **Region:** ap-south-1  **Completion date:** ______

## 1. Architecture and inventory (15)
Diagram + table of actual IDs (paste `terraform output inventory`):
| Resource | ID | CIDR / IP |
|---|---|---|
| ewb-vpc-a | vpc-... | 10.10.0.0/16 |
| ewb-vpc-b | vpc-... | 10.20.0.0/16 |
| ... | | |

## 2. Subnets, IGW, route associations (20)
Screenshots: Checkpoint 01 (subnet associations, public default route; private table local-only).

## 3. Peering and routes (20)
Screenshots: Checkpoint 03 (Active, both VPC IDs), Checkpoint 04 (all three route tables + associations).
Explain the forward path and return path in your own words:

## 4. Security rules and private SSH (20)
Screenshots of inbound rules for each SG. SSH proof: `ssh ewb-app-b` through the bastion.

## 5. Tests with explanations (15)
| Test | Screenshot / output | Result | Explanation |
|---|---|---|---|
| 01 Baseline (before peering) | | No replies | |
| 02 Forward ping A->B | | 4/4, 0% loss | |
| 03 Reverse ping B->A | | 4/4, 0% loss | |
| 04 Private SSH | | Shell on App-B | |
| 05 Isolation (no public IPv4) | | | |
| 06 Controlled failure + recovery | | stops, then resumes | |
| 07 Full-stack app (dashboard + notes) | | | |

## 6. Cleanup and reflection (10)
Cleanup evidence (tag-filtered consoles empty, billing check). What I learned:
