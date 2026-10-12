provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.tags, {
      Environment = var.environment
      Layer       = "40-eks"
    })
  }
}
