terraform {
  backend "s3" {
    bucket = "servian-terraform-state-351f18ef"
    key    = "terraform.tfstate"
    region = "eu-west-2"

    dynamodb_table = "servian-terraform-lock-351f18ef"
    encrypt        = true
  }
}