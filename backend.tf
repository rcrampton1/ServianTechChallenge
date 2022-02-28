#------------------------------------------------
# To setup state for terraform
#------------------------------------------------

terraform {
  backend "s3" {
    bucket = "servian-terraform-state" #hard coded look to replace
    key    = "terraform.tfstate"
    region = "eu-west-1" #hard coded look to replace

    dynamodb_table = "servian-terraform-lock" #hard coded look to replace
    encrypt        = true
  }
}