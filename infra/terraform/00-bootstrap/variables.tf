variable "region" {
  type    = string
  default = "us-east-1"
}

variable "org" {
  description = "Short organization code used in resource names (Monteiro Financial Services)."
  type        = string
  default     = "mfs"

  validation {
    condition     = can(regex("^[a-z0-9]{2,5}$", var.org))
    error_message = "org must be 2-5 lowercase alphanumeric characters."
  }
}

variable "alert_email" {
  type = string
}

variable "public_zone_name" {
  description = "Hosted zone delegated from the parent domain. Empty string skips it."
  type        = string
  default     = "aws.edymonte.com.br"
}

variable "enable_budget" {
  type    = bool
  default = true
}

variable "monthly_budget_usd" {
  type    = number
  default = 100
}

variable "tags" {
  type = map(string)
  default = {
    Owner      = "edilson"
    CostCenter = "learning"
    Project    = "aws-enterprise-platform"
    ManagedBy  = "Terraform"
  }
}
