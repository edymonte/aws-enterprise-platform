variable "alert_email" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.70.0.0/16"
}

variable "single_nat_gateway" {
  description = "One NAT for the whole VPC (cheap, single-AZ egress risk) vs one per AZ."
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = "ECR, STS, Logs and Secrets Manager endpoints (cost per AZ-hour)."
  type        = bool
  default     = false
}

variable "operator_ip_ranges" {
  description = "Operator public CIDRs (home IP /32). Used by the EKS API and the ALB."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.operator_ip_ranges : can(cidrnetmask(c)) && c != "0.0.0.0/0"])
    error_message = "operator_ip_ranges must be valid, restricted CIDRs (0.0.0.0/0 is not allowed)."
  }
}
