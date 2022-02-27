#---------------------------------------------------
# Basic VPC setup for settings
#---------------------------------------------------

module "networking" {
  source = "./modules/network" # Used Module to reduce code in main block

  project              = var.common_name
  environment          = var.common_name
  region               = var.region
  availability_zones   = data.aws_availability_zones.availability_zones.names
  vpc_cidr             = var.vpc_cidr
  public_subnets_cidr  = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr
}

#------------------------------------------------
# IAM - Logging / secret access 
#------------------------------------------------

data "aws_iam_policy_document" "ecs_log_permissions" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "ecs_secret_permissions" {
  name        = "ecs-secret-policy"
  description = "A policy to allow secret retrieval"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1645804564154",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecrets"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}


resource "aws_iam_role" "ecs_tasks_execution_role" {
  name               = "${var.common_name}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_log_permissions.json
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.ecs_tasks_execution_role.name
  policy_arn = aws_iam_policy.ecs_secret_permissions.arn
}

resource "aws_iam_role_policy_attachment" "ecs_tasks_execution_role" {
  role       = aws_iam_role.ecs_tasks_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#------------------------------------------------
# AWS Secret Manager
#------------------------------------------------

resource "aws_secretsmanager_secret" "secretmaster" {
  name                    = "${var.common_name}_secretsmanager_ecs"
  recovery_window_in_days = 0 # to allow recreate but best change this in production setting
}

resource "aws_secretsmanager_secret_version" "sversion" {
  secret_id     = aws_secretsmanager_secret.secretmaster.id
  secret_string = <<EOF
   {
    "db_username": "${var.db_username}",
    "db_password": "${random_password.db_password.result}",
    "db_url":   "${aws_rds_cluster.aws_rds_cluster.endpoint}",
    "db_name":  "${var.db_name}"
   }
EOF
}

#------------------------------------------------
# ELB - ALB
#------------------------------------------------

resource "aws_security_group" "elb_sg" {
  name        = "${var.common_name}-elb-sg"
  description = "Allow Access from Cloudfront CDN"
  vpc_id      = module.networking.vpc_id

  ingress = [
    {
      description      = "port 80 from internet"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      security_groups  = []
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      self             = false
    },
    {
      description      = "port 443 from internet"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      security_groups  = []
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      self             = false
    }
  ]

  egress = [
    {
      description      = "system healthcheck"
      from_port        = "${var.app_port}"
      to_port          = "${var.app_port}"
      protocol         = "tcp"
      cidr_blocks      = [data.aws_vpc.created.cidr_block]
      security_groups  = []
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      self             = false
    }
  ]

  tags = {
    Name = "${var.common_name}-elb-sg"
  }
}


resource "aws_lb" "app" {
  name               = "${var.common_name}-elb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb_sg.id]
  subnets            = module.networking.public_subnets_id

}


resource "aws_lb_target_group" "target_group" {
  name        = "${var.common_name}-target-group"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.networking.vpc_id

  health_check {
    path = "/healthcheck"
  }

}

resource "aws_lb_listener" "app_80" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/restrict-access-to-load-balancer.html 
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "No Access direct to ALB"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "app_80_CF" {
  listener_arn = aws_lb_listener.app_80.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

  condition {
    http_header {
      http_header_name = var.origin_header_name
      values           = ["${var.origin_header_key}"]
    }
  }

}
