#------------------------------------------------
# ECS Cluster
#------------------------------------------------

resource "aws_ecs_cluster" "cluster" {
  name = "${var.common_name}_ecs_cluster"
}

# ECS Cluster Security group
resource "aws_security_group" "webapp" {
  name        = "${var.common_name}-webapp"
  description = "Allow connections from server to webapp on port 3000"
  vpc_id      = module.networking.vpc_id

  ingress {
    description = "Web app exposed on set port"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.created.cidr_block] # change to LB
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.common_name}-webapp-sg"
  }
}


#------------------------------------------------
# ECS taskdefinition
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html
#------------------------------------------------

resource "aws_cloudwatch_log_group" "default" {
  name              = "/ecs/${var.common_name}"
  retention_in_days = 30
}

# ECS taskdefinition application
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.common_name}_application"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_tasks_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.container_image
      essential = true
      cpu       = 128
      memory    = 256
      command   = ["serve"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = "${var.region}"
          awslogs-group         = aws_cloudwatch_log_group.default.name
          awslogs-stream-prefix = "app"
        }
      }
      secrets = [
        {
          "valueFrom" : "${aws_secretsmanager_secret.secretmaster.id}:db_password::",
          "name" : "VTT_DBPASSWORD"
        }
      ]
      environment = [
        { "name" : "VTT_DBHOST", "value" : "${aws_rds_cluster.aws_rds_cluster.endpoint}" },
        { "name" : "VTT_DBPORT", "value" : "${var.db_port}" },
        { "name" : "VTT_DBUSER", "value" : "${var.db_username}" },
        { "name" : "VTT_DBNAME", "value" : "${var.db_name}" },
        { "name" : "VTT_LISTENHOST", "value" : "0.0.0.0" }
      ]
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])
}

# ECS taskdefinition Database setup

resource "aws_ecs_task_definition" "rds" {
  family                   = "${var.common_name}_setup_db"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_tasks_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "Database"
      image     = var.container_image
      essential = true
      cpu       = 128
      memory    = 256
      command   = ["updatedb", "-s"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = "${var.region}"
          awslogs-group         = aws_cloudwatch_log_group.default.name
          awslogs-stream-prefix = "rds"
        }
      }
      secrets = [
        {
          "valueFrom" : "${aws_secretsmanager_secret.secretmaster.id}:db_password::",
          "name" : "VTT_DBPASSWORD"
        }
      ]
      environment = [
        { "name" : "VTT_DBHOST", "value" : "${aws_rds_cluster.aws_rds_cluster.endpoint}" },
        { "name" : "VTT_DBPORT", "value" : "${var.db_port}" },
        { "name" : "VTT_DBUSER", "value" : "${var.db_username}" },
        { "name" : "VTT_DBNAME", "value" : "${var.db_name}" },
        { "name" : "VTT_LISTENHOST", "value" : "0.0.0.0" }
      ]
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])

}

#------------------------------------------------
# ECS service DBA
# - needs more research into tasks/ but doesn't 
#   look supported in terraform yet 
#------------------------------------------------

resource "aws_ecs_service" "rds" {
  name            = "rds_setup"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.rds.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  depends_on      = [aws_rds_cluster.aws_rds_cluster]

  network_configuration {
    subnets          = module.networking.private_subnets_id
    assign_public_ip = true
    security_groups  = [aws_security_group.webapp.id]
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

}

#------------------------------------------------
# ECS Service app
#------------------------------------------------

resource "aws_ecs_service" "app" {
  name            = "app"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "app"
    container_port   = 3000
  }

  network_configuration {
    subnets          = module.networking.private_subnets_id
    assign_public_ip = true
    security_groups  = [aws_security_group.webapp.id]
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}


#------------------------------------------------
# Auto scale settings for webapp
#------------------------------------------------

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  name               = "memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = 80
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 80
  }
}


#------------------------------------------------
# ECR 
#------------------------------------------------

# Todo - look at creating ECR so not pulling directly from Dockerhub

#resource "aws_ecr_repository" "ecr" {
#  name                 = "${var.common_name}-ecr"
#  image_tag_mutability = "MUTABLE"
#
#  image_scanning_configuration {
#    scan_on_push = true
#  }
#}
#
#resource "aws_ecr_lifecycle_policy" "main" {
#  repository = aws_ecr_repository.ecr.name
#
#  policy = jsonencode({
#    rules = [{
#      rulePriority = 1
#      description  = "keep last 10 images"
#      action = {
#        type = "expire"
#      }
#      selection = {
#        tagStatus   = "any"
#        countType   = "imageCountMoreThan"
#        countNumber = 10
#      }
#    }]
#  })
#}
