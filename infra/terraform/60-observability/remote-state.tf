# Upstream layer outputs (layered state: each layer owns its S3 object).

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "10-network.tfstate"
    region = var.state_region
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "40-eks.tfstate"
    region = var.state_region
  }
}

variable "state_bucket" {
  description = "Output of 00-bootstrap (written to .runtime/common.tfvars.json)."
  type        = string
}

variable "state_region" {
  type    = string
  default = "us-east-1"
}
