module "queueguard" {
  source              = "./modules/queueguard"
  name_prefix         = "queueguard-${var.environment}"
  alert_email         = var.alert_email
  log_retention_days  = var.log_retention_days
}
