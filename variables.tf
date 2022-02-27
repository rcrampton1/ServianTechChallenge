#------------------------------------------------
# System and General variables
#------------------------------------------------

variable "region" {
  default = "eu-west-1"
}

variable "common_name" {
  description = "Common name for created items"
  default     = "servian"
}

variable "pr_number" {
  default = "null"
}

variable "vpc_cidr" {
  description = "The CIDR block of the vpc"
  default     = "10.0.0.0/16"
}

variable "public_subnets_cidr" {
  type        = list(any)
  description = "The CIDR block for the public subnet"
  default     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]

}

variable "private_subnets_cidr" {
  type        = list(any)
  description = "The CIDR block for the private subnet"
  default     = ["10.0.40.0/24", "10.0.50.0/24", "10.0.60.0/24"]
}

#------------------------------------------------
# Cloudfront variables
#------------------------------------------------

variable "cf_config" {
  default = {
    price_class = "PriceClass_All"
  }
}

variable "origin_header_name" {
  default = "X-Custom_header"
}

variable "origin_header_key" {
  default = "random-test-key1234"
}

#------------------------------------------------
# App Vars 
#------------------------------------------------

variable "app_count" {
  type    = number
  default = 2
}

variable "container_image" {
  description = "Application container image"
  default     = "servian/techchallengeapp:latest"
}

variable "app_port" {
  description = "Application container port"
  default     = "3000"
}


#------------------------------------------------
# Database Vars -
#------------------------------------------------

variable "rds_engine" {
  description = "Rds engine for DB type PostgreSQL"
  default     = "aurora-postgresql"
}

variable "db_name" {
  description = "RDS DB name for service"
  default     = "postgresql"
}

variable "db_username" {
  description = "RDS database username"
  default     = "postgresql"
}

variable "db_port" {
  description = "RDS database port number"
  default     = "5432"
}

variable "db_password" {
  description = "RDS database password"
  default     = "test"
  sensitive   = true
}
