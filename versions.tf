terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
  backend "s3" {
    # Replace with your own private, versioned bucket before terraform init.
    bucket       = "REPLACE_WITH_YOUR_TERRAFORM_STATE_BUCKET"
    key          = "queueguard/dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "QueueGuard"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
