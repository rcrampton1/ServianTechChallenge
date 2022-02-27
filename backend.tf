terraform {
  backend "s3" {
    bucket = "servian-terraform-state-80c72620"
    key    = "terraform.tfstate"
    region = "eu-west-1"

    dynamodb_table = "servian-terraform-lock-80c72620"
    encrypt        = true
  }
}