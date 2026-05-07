output "vpc_id_b" {
  value = aws_vpc.main_b.id
}

output "alb_dns_name" {
  value = aws_lb.backend.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.backend.name
}

output "vpc_peering_id" {
  value = aws_vpc_peering_connection.peer.id
}

output "private_route_table_id_b" {
  description = "Route table ID in Account B (for verification)"
  value       = aws_route_table.private_b.id
}