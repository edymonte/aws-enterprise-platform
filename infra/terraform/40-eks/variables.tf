variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT (cheaper; interruptions become a game day)."
  type        = string
  default     = "ON_DEMAND"
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "extra_admin_access_entries" {
  description = "Additional EKS access entries (e.g. an SSO admin role), module v21 format."
  type        = any
  default     = {}
}
