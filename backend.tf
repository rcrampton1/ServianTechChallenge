terraform {
  backend "s3" {
    bucket = "servian-terraform-state-6887f543"
    key    = "terraform.tfstate"
    region = "eu-west-2"

    dynamodb_table = "servian-terraform-lock-6887f543"
    encrypt        = true
  }
}