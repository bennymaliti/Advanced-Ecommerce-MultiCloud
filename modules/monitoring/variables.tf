variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "alert_email_addresses" {
  description = "List of email addresses for alerts"
  type        = list(string)
  default     = []
}

variable "alb_unhealthy_alarm_name" {
  description = "Name of ALB unhealthy hosts alarm"
  type        = string
  default     = ""
}

variable "rds_cpu_alarm_name" {
  description = "Name of RDS CPU alarm"
  type        = string
  default     = ""
}

variable "cache_cpu_alarm_name" {
  description = "Name of Cache CPU alarm"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}