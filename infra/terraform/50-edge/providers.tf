# CloudFront, its ACM certificate and CLOUDFRONT-scoped WAF must live in us-east-1.
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = merge(var.tags, {
      Environment = var.environment
      Layer       = "50-edge"
    })
  }
}

# Second region for the DR lab (static maintenance site).
provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = merge(var.tags, {
      Environment = var.environment
      Layer       = "50-edge"
    })
  }
}
