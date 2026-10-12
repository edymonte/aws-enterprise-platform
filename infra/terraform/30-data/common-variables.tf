# Variables shared by every layer (values come from .runtime/common.tfvars.json).

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "org" {
  type    = string
  default = "mfs"
}

variable "environment" {
  type    = string
  default = "lab"
}

variable "name_suffix" {
  description = "Stable suffix from 00-bootstrap: globally unique names survive the daily down/up."
  type        = string
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
