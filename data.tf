#------------------------------------------------
# Collect data on account
#------------------------------------------------

data "aws_availability_zones" "availability_zones" {
  state = "available"
}

data "aws_vpc" "created" {
  id = module.networking.vpc_id
}


# Create random string password for Database
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}
