terraform {
  backend "s3" {
    bucket = "servian-terraform-state"
    key    = "terraform.tfstate"
    region = "eu-west-1"

    dynamodb_table = "servian-terraform-lock"
    encrypt        = true
  }
}