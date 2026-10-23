variable "aws_region" {
  description = "AWS region for the stack"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "alert_email" {
  description = "Optional email for alarm notifications; leave empty to disable subscription"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  type    = number
  default = 14
}
