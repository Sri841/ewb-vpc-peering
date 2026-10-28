output "inventory" {
  description = "Record these IDs in your report (workbook Checkpoints 01-04)"
  value = {
    vpc_a_id       = aws_vpc.a.id
    vpc_b_id       = aws_vpc.b.id
    subnets        = { a_public = aws_subnet.a_public.id, a_private = aws_subnet.a_private.id, b_private = aws_subnet.b_private.id }
    route_tables   = { a_public = aws_route_table.a_public.id, a_private = aws_route_table.a_private.id, b_private = aws_route_table.b_private.id }
    igw_id         = aws_internet_gateway.a.id
    peering_id     = var.enable_peering ? aws_vpc_peering_connection.ab[0].id : "peering disabled (baseline)"
    instances      = { bastion = aws_instance.bastion.id, app_a = aws_instance.app_a.id, app_b = aws_instance.app_b.id }
    private_ips    = { bastion = var.bastion_ip, app_a = var.app_a_ip, app_b = var.app_b_ip }
    bastion_public = aws_instance.bastion.public_ip
  }
}
