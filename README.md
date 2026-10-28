# EWB AWS VPC Peering - Full-Stack Project

Implements the **EWB Courses "AWS VPC Peering" student workbook** as code, plus a small full-stack app whose traffic really flows over the peering connection.

```
Browser --(SSH tunnel)--> Bastion --> App-A (VPC A, 10.10.2.10)  --[ VPC peering ]-->  App-B (VPC B, 10.20.1.10)
                          10.10.1.10   web UI + API (port 8080)                       data service (port 9000)
```

| Layer | What | Where |
|---|---|---|
| Infrastructure | VPCs, subnets, IGW, route tables, peering, security groups, 3 EC2s, key pair, ssh_config | `terraform/` |
| Frontend | Dashboard (status cards, ping test, notes board) | `app/app-a/static/` |
| Backend API | Serves UI, proxies to App-B, runs ping | `app/app-a/server.py` |
| Data service | Notes storage in VPC B | `app/app-b/server.py` |
| Automation | deploy, tunnel, workbook tests, local run | `scripts/` |
| Report | Template matching the workbook checklist and marks | `docs/REPORT_TEMPLATE.md` |

The app uses only the Python standard library, because the private instances have no internet access (the lab has no NAT gateway).

## Prerequisites
VS Code, Terraform >= 1.5, AWS CLI configured for your lab account, OpenSSH (WSL on Windows), Python 3. Install the recommended VS Code extensions when prompted.

## 0. Try the app locally (no AWS needed)
`Terminal > Run Task > Run app locally` (or `bash scripts/run-local.sh`), then open http://localhost:8080.

## 1. Configure and build the baseline (workbook pages 5-8)
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars   # edit name + your /32 IP
terraform -chdir=terraform init
terraform -chdir=terraform apply -var enable_peering=false          # VPCs, subnets, IGW, SGs, instances - NO peering
bash scripts/tests.sh baseline                                       # Test 01: expect NO replies
```
Screenshot checkpoints 01 and 02 in the AWS console (subnet associations, public route, instance IPs). Terraform output `inventory` lists every ID.

## 2. Activate peering and routes (pages 9-10)
```bash
terraform -chdir=terraform apply        # enable_peering defaults to true
bash scripts/tests.sh after             # Tests 02-06
```
This creates `ewb-a-b-peer` (auto-accepted: same account + Region) and the three peer routes, including the one in the **public** route table that the bastion needs for ProxyJump to App-B. Screenshot checkpoints 03 and 04.

## 3. Deploy the full-stack app
```bash
bash scripts/deploy.sh      # copies code through the bastion, starts systemd services
bash scripts/tunnel.sh      # keep running; open http://localhost:8080
```
Post a note: browser -> App-A API -> peering -> App-B storage. The UI shows the source IP App-B saw (10.10.2.10).

## 4. Controlled failure (page 11)
```bash
terraform -chdir=terraform apply -var enable_app_b_icmp_rule=false   # removes ONLY the ICMP rule on App-B
bash scripts/tests.sh after                                           # forward ping fails; SSH still works
terraform -chdir=terraform apply                                      # restore - replies resume
```
Extra experiments: `-var enable_app_ports=false` breaks the dashboard (TCP 9000 blocked) while ping still works. This shows that routing and security groups are separate layers.

## 5. Submit (pages 13)
Fill in `docs/REPORT_TEMPLATE.md`, add labelled screenshots and export to `YourName_EWB_VPC_Peering.pdf`. Never include `.keys/ewb-lab.pem`.

## 6. Clean up (page 14)
```bash
terraform -chdir=terraform destroy
```
Then filter by tag `Project = EWB-VPC-Peering` in EC2/VPC consoles, check volumes and public IPv4 addresses, and capture evidence. Delete local `.keys/`.

## Notes and assumptions
- The workbook describes a manual console build. This project automates it, but do the console steps at least once to learn them and take your screenshots.
- Terraform generates the `ewb-lab` key pair; the private key is written to `.keys/` (git-ignored) and is also in your local Terraform state. Protect the state file and never commit it.
- Extra rules beyond the workbook (clearly marked, scoped /32): bastion -> App-A TCP 8080 and App-A -> App-B TCP 9000, both toggled by `enable_app_ports`.
- If your public IP changes, update `my_ip_cidr` and re-apply; if the bastion is stopped and restarted its public IP changes, so re-apply to regenerate `ssh_config`.
- Costs: 3 x t3.micro + EBS + 1 public IPv4. No NAT gateway. Destroy when finished.
