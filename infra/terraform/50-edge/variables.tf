variable "zone_name" {
  type    = string
  default = "aws.edymonte.com.br"
}

variable "prod_host_label" {
  type    = string
  default = "portal"
}

variable "dev_host_label" {
  type    = string
  default = "portal-dev"
}

variable "dr_host_label" {
  type    = string
  default = "portal-dr"
}

variable "alb_name_override" {
  description = "Look up a different ALB (e.g. to test the edge layer alone)."
  type        = string
  default     = ""
}

variable "waf_mode" {
  type    = string
  default = "count"

  validation {
    condition     = contains(["count", "block"], var.waf_mode)
    error_message = "waf_mode must be count or block."
  }
}

variable "waf_rate_limit_per_5min" {
  description = "Requests per 5 minutes per client IP (AWS WAF rate-based window)."
  type        = number
  default     = 1000
}

variable "origin_verify_header" {
  description = "Value CloudFront sends in X-Origin-Verify. Not a strong secret: rotate it, and prefer VPC origins in production."
  type        = string
  default     = "change-me-mfs-lab"
}

variable "enable_dr_lab" {
  type    = bool
  default = false
}

variable "dr_region" {
  type    = string
  default = "sa-east-1"
}
