terraform {
  backend "s3" {
    bucket = "servian-terraform-state-65823141"
    key    = "terraform.tfstate"
    region = "eu-west-2"

    dynamodb_table = "servian-terraform-lock-65823141"
    encrypt        = true
  }
}