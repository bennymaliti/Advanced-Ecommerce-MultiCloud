output "cache_cluster_id" {
  description = "ID of the ElastiCache replication group"
  value       = aws_elasticache_replication_group.main.id
}

output "cache_primary_endpoint" {
  description = "Primary endpoint for the cache cluster"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "cache_reader_endpoint" {
  description = "Reader endpoint for the cache cluster"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "cache_port" {
  description = "Port number for the cache"
  value       = 6379
}

output "cache_nodes" {
  description = "List of cache nodes"
  value       = aws_elasticache_replication_group.main.member_clusters
}