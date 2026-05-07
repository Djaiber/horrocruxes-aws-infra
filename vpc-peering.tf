# ═══════════════════════════════════════════════════════════════════════════
# VPC Peering: Account B → Account A
# ═══════════════════════════════════════════════════════════════════════════

# Peering connection (requested from Account B)
resource "aws_vpc_peering_connection" "peer" {
  provider      = aws.account_b
  peer_owner_id = var.account_id_a
  peer_vpc_id   = var.vpc_id_a
  vpc_id        = aws_vpc.main_b.id
  auto_accept   = false # Requires acceptance in Account A

  tags = {
    Name        = "${var.project_name}-peer-a-to-b-${var.environment}"
    Side        = "Requester"
    FromAccount = var.account_id_b
    ToAccount   = var.account_id_a
  }
}

# Accept the peering in Account A
resource "aws_vpc_peering_connection_accepter" "peer_a" {
  provider                  = aws.account_a
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true

  tags = {
    Name = "${var.project_name}-peer-a-to-b-${var.environment}"
    Side = "Accepter"
  }
}

# ── Route in Account B → Account A (for ECS to reach RDS) ──────────────────
resource "aws_route" "from_b_to_a" {
  provider                  = aws.account_b
  route_table_id            = aws_route_table.private_b.id
  destination_cidr_block    = var.cidr_account_a
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# ── Return Route in Account A → Account B (for RDS to reach ECS) ────────
resource "aws_route" "from_a_to_b" {
  provider                  = aws.account_a
  count                     = length(var.private_route_table_ids_a)
  route_table_id            = var.private_route_table_ids_a[count.index]
  destination_cidr_block    = var.cidr_account_b
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}