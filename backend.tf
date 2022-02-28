terraform {
  backend "s3" {
    bucket = "servian-terraform-state-502e764a"
    key    = "terraform.tfstate"
    region = "eu-west-2"

    dynamodb_table = "servian-terraform-lock-502e764a"
    encrypt        = true
  }
}