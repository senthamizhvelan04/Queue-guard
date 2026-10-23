output "api_url" {
  description = "Base URL for QueueGuard API"
  value       = module.queueguard.api_url
}

output "orders_table_name" {
  value = module.queueguard.orders_table_name
}

output "queue_name" {
  value = module.queueguard.queue_name
}

output "dlq_name" {
  value = module.queueguard.dlq_name
}
