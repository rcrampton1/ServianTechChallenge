terraform {
  required_version = "> 0.13.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.2.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = "Interview"
      Service     = "${var.common_name}"
      Company     = "${var.common_name}"
      Github_ref  = "${var.pr_number}"
    }
  }
}