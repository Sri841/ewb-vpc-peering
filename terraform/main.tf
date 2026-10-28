data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  az = data.aws_availability_zones.available.names[0]
}

# ---------------- Key pair (private key stays on your laptop in ../.keys) ----------------
resource "tls_private_key" "lab" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "lab" {
  key_name   = "ewb-lab"
  public_key = tls_private_key.lab.public_key_openssh
}

resource "local_sensitive_file" "pem" {
  content         = tls_private_key.lab.private_key_pem
  filename        = "${path.module}/../.keys/ewb-lab.pem"
  file_permission = "0400"
}

# ---------------- VPC A ----------------
resource "aws_vpc" "a" {
  cidr_block           = var.vpc_a_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "ewb-vpc-a" }
}

resource "aws_subnet" "a_public" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = var.a_public_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags                    = { Name = "ewb-a-public" }
}

resource "aws_subnet" "a_private" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = var.a_private_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags                    = { Name = "ewb-a-private" }
}

resource "aws_internet_gateway" "a" {
  vpc_id = aws_vpc.a.id
  tags   = { Name = "ewb-igw-a" }
}

resource "aws_route_table" "a_public" {
  vpc_id = aws_vpc.a.id
  tags   = { Name = "ewb-rt-a-public" }
}

resource "aws_route" "a_public_igw" {
  route_table_id         = aws_route_table.a_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.a.id
}

resource "aws_route_table_association" "a_public" {
  subnet_id      = aws_subnet.a_public.id
  route_table_id = aws_route_table.a_public.id
}

resource "aws_route_table" "a_private" {
  vpc_id = aws_vpc.a.id
  tags   = { Name = "ewb-rt-a-private" } # local route only (no internet route)
}

resource "aws_route_table_association" "a_private" {
  subnet_id      = aws_subnet.a_private.id
  route_table_id = aws_route_table.a_private.id
}

# ---------------- VPC B (no internet gateway) ----------------
resource "aws_vpc" "b" {
  cidr_block           = var.vpc_b_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "ewb-vpc-b" }
}

resource "aws_subnet" "b_private" {
  vpc_id                  = aws_vpc.b.id
  cidr_block              = var.b_private_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags                    = { Name = "ewb-b-private" }
}

resource "aws_route_table" "b_private" {
  vpc_id = aws_vpc.b.id
  tags   = { Name = "ewb-rt-b-private" }
}

resource "aws_route_table_association" "b_private" {
  subnet_id      = aws_subnet.b_private.id
  route_table_id = aws_route_table.b_private.id
}

# ---------------- Peering + routes on both sides ----------------
resource "aws_vpc_peering_connection" "ab" {
  count       = var.enable_peering ? 1 : 0
  vpc_id      = aws_vpc.a.id # requester
  peer_vpc_id = aws_vpc.b.id # accepter
  auto_accept = true         # same account + Region: request is accepted for you
  tags        = { Name = "ewb-a-b-peer" }
}

resource "aws_route" "a_private_to_b" {
  count                     = var.enable_peering ? 1 : 0
  route_table_id            = aws_route_table.a_private.id
  destination_cidr_block    = var.vpc_b_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.ab[0].id
}

resource "aws_route" "b_private_to_a" {
  count                     = var.enable_peering ? 1 : 0
  route_table_id            = aws_route_table.b_private.id
  destination_cidr_block    = var.vpc_a_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.ab[0].id
}

# ProxyJump: the bastion opens the SSH connection to App-B, so the PUBLIC subnet needs the peering route too.
resource "aws_route" "a_public_to_b" {
  count                     = var.enable_peering ? 1 : 0
  route_table_id            = aws_route_table.a_public.id
  destination_cidr_block    = var.vpc_b_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.ab[0].id
}

# ---------------- Security groups (/32 scoped, workbook page 6) ----------------
resource "aws_security_group" "bastion" {
  name        = "ewb-sg-bastion"
  description = "Bastion SSH from my IP"
  vpc_id      = aws_vpc.a.id
  tags        = { Name = "ewb-sg-bastion" }
}

resource "aws_security_group" "app_a" {
  name        = "ewb-sg-app-a"
  description = "App-A"
  vpc_id      = aws_vpc.a.id
  tags        = { Name = "ewb-sg-app-a" }
}

resource "aws_security_group" "app_b" {
  name        = "ewb-sg-app-b"
  description = "App-B"
  vpc_id      = aws_vpc.b.id
  tags        = { Name = "ewb-sg-app-b" }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH from my public IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.my_ip_cidr
}

resource "aws_vpc_security_group_ingress_rule" "app_a_ssh" {
  security_group_id = aws_security_group.app_a.id
  description       = "SSH from bastion private IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${var.bastion_ip}/32"
}

resource "aws_vpc_security_group_ingress_rule" "app_a_icmp_from_b" {
  security_group_id = aws_security_group.app_a.id
  description       = "ICMP echo request from App-B"
  ip_protocol       = "icmp"
  from_port         = 8 # ICMP type
  to_port           = 0 # ICMP code
  cidr_ipv4         = "${var.app_b_ip}/32"
}

resource "aws_vpc_security_group_ingress_rule" "app_b_ssh" {
  security_group_id = aws_security_group.app_b.id
  description       = "SSH from bastion private IP (ProxyJump source)"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${var.bastion_ip}/32"
}

# Toggle with -var enable_app_b_icmp_rule=false for the controlled failure test
resource "aws_vpc_security_group_ingress_rule" "app_b_icmp_from_a" {
  count             = var.enable_app_b_icmp_rule ? 1 : 0
  security_group_id = aws_security_group.app_b.id
  description       = "ICMP echo request from App-A"
  ip_protocol       = "icmp"
  from_port         = 8
  to_port           = 0
  cidr_ipv4         = "${var.app_a_ip}/32"
}

# Extra rules for the full-stack demo (not in the base workbook)
resource "aws_vpc_security_group_ingress_rule" "app_a_web_from_bastion" {
  count             = var.enable_app_ports ? 1 : 0
  security_group_id = aws_security_group.app_a.id
  description       = "Dashboard via SSH tunnel through bastion"
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  cidr_ipv4         = "${var.bastion_ip}/32"
}

resource "aws_vpc_security_group_ingress_rule" "app_b_api_from_a" {
  count             = var.enable_app_ports ? 1 : 0
  security_group_id = aws_security_group.app_b.id
  description       = "Data service API from App-A over peering"
  ip_protocol       = "tcp"
  from_port         = 9000
  to_port           = 9000
  cidr_ipv4         = "${var.app_a_ip}/32"
}

# Default outbound allow-all (beginner lab)
resource "aws_vpc_security_group_egress_rule" "bastion" {
  security_group_id = aws_security_group.bastion.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_a" {
  security_group_id = aws_security_group.app_a.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_b" {
  security_group_id = aws_security_group.app_b.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------- EC2 instances ----------------
resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.a_public.id
  private_ip                  = var.bastion_ip
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.lab.key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags       = { Name = "ewb-bastion" }
  depends_on = [aws_route.a_public_igw, aws_route_table_association.a_public]
}

resource "aws_instance" "app_a" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.a_private.id
  private_ip                  = var.app_a_ip
  vpc_security_group_ids      = [aws_security_group.app_a.id]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.lab.key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "ewb-app-a" }
}

resource "aws_instance" "app_b" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.b_private.id
  private_ip                  = var.app_b_ip
  vpc_security_group_ids      = [aws_security_group.app_b.id]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.lab.key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = { Name = "ewb-app-b" }
}

# ---------------- Generated ssh_config (ProxyJump, workbook page 8) ----------------
resource "local_file" "ssh_config" {
  filename        = "${path.module}/../ssh_config"
  file_permission = "0600"
  content         = <<-EOT
    Host *
        User ec2-user
        IdentityFile ${abspath("${path.module}/../.keys/ewb-lab.pem")}
        IdentitiesOnly yes
        UserKnownHostsFile ${abspath("${path.module}/../.keys")}/known_hosts
        StrictHostKeyChecking accept-new

    Host ewb-bastion
        HostName ${aws_instance.bastion.public_ip}

    Host ewb-app-a
        HostName ${var.app_a_ip}
        ProxyJump ewb-bastion

    Host ewb-app-b
        HostName ${var.app_b_ip}
        ProxyJump ewb-bastion
  EOT
}
