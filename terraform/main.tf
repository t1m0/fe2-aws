terraform {
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.54.0"
    }
  }

  backend "s3" {
    # Backend configuration should be provided via:
    # 1. Backend config file: terraform init -backend-config=backend.hcl
    # 2. CLI flags: terraform init -backend-config="bucket=my-bucket" ...
    # Required parameters: bucket, key, region
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  project_name = "fe2-app"
  fe2_port     = 64112
  mongodb_port = 27017
}
