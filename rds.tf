#------------------------------------------------
# Database - RDS aurora Serverless
#------------------------------------------------

# create the subnet group for RDS instance
resource "aws_db_subnet_group" "rds-subnet-group" {
  name       = "${var.common_name}-rds-subnet-group"
  subnet_ids = module.networking.private_subnets_id
}

# create the parameter group
resource "aws_rds_cluster_parameter_group" "default" {
  name        = "aurora-postgresql10"
  family      = "aurora-postgresql10"
  description = "RDS default cluster parameter group"
}

# create the RDS cluster
resource "aws_rds_cluster" "aws_rds_cluster" {
  port                            = "5432"
  cluster_identifier              = "${var.common_name}-aurora-rds"
  db_cluster_parameter_group_name = "aurora-postgresql10"
  db_subnet_group_name            = aws_db_subnet_group.rds-subnet-group.id
  vpc_security_group_ids          = [aws_security_group.rds.id]
  engine                          = var.rds_engine
  engine_mode                     = "serverless"
  engine_version                  = "10.14"
  database_name                   = var.db_name
  master_password                 = random_password.db_password.result
  master_username                 = var.db_username
  deletion_protection             = "false"
  skip_final_snapshot             = true
  backup_retention_period         = "7"

  scaling_configuration {
    auto_pause               = true
    min_capacity             = 2
    max_capacity             = 2
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }

  tags = {
    Name = "${var.common_name}-rds-sg"
  }
}

# create security Group
resource "aws_security_group" "rds" {
  name        = "${var.common_name}-rds"
  description = "Allow connections from server to db on port 5432"
  vpc_id      = module.networking.vpc_id

  ingress = [
    {
      description      = "port 5432 postgres"
      from_port        = "${var.db_port}"
      to_port          = "${var.db_port}"
      protocol         = "tcp"
      security_groups  = [aws_security_group.webapp.id]
      cidr_blocks      = []
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      self             = false
    }
  ]

  tags = {
    Name = "${var.common_name}-rds-sg"
  }
}

