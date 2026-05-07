# ═══════════════════════════════════════════════════════════════════════════
# ECR
# ═══════════════════════════════════════════════════════════════════════════
resource "aws_ecr_repository" "backend" {
  provider             = aws.account_b
  name                 = "${var.project_name}-backend-${var.environment}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ═══════════════════════════════════════════════════════════════════════════
# ECS Cluster
# ═══════════════════════════════════════════════════════════════════════════
resource "aws_ecs_cluster" "main" {
  provider = aws.account_b
  name     = "${var.project_name}-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ═══════════════════════════════════════════════════════════════════════════
# IAM Roles
# ═══════════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "ecs_execution" {
  provider = aws.account_b
  name     = "${var.project_name}-ecs-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "ecs_task_secrets" {
  provider = aws.account_b
  name     = "${var.project_name}-secrets-access-${var.environment}"
  role     = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          "arn:aws:secretsmanager:us-east-1:${var.account_id_b}:secret:GOOGLE_API_KEY-wQtItx",
          "arn:aws:secretsmanager:us-east-1:${var.account_id_b}:secret:LAMBDA_API_KEY-8x9kra",
          "arn:aws:secretsmanager:us-east-1:${var.account_id_b}:secret:LAMBDA_URL-AEuOlS"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy" "ecs_exec" {
  provider = aws.account_b
  name     = "${var.project_name}-ecs-exec-${var.environment}"
  role     = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  provider   = aws.account_b
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  provider = aws.account_b
  name     = "${var.project_name}-ecs-task-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ═══════════════════════════════════════════════════════════════════════════
# CloudWatch Logs
# ═══════════════════════════════════════════════════════════════════════════
resource "aws_cloudwatch_log_group" "backend" {
  provider          = aws.account_b
  name              = "/ecs/${var.project_name}-backend-${var.environment}"
  retention_in_days = 30
}

# ═══════════════════════════════════════════════════════════════════════════
# Security Groups
# ═══════════════════════════════════════════════════════════════════════════
resource "aws_security_group" "alb" {
  provider    = aws.account_b
  name        = "${var.project_name}-alb-sg-${var.environment}"
  description = "ALB security group"
  vpc_id      = aws_vpc.main_b.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {                          
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg-${var.environment}"
  }
}

resource "aws_security_group" "ecs_task" {
  provider    = aws.account_b
  name        = "${var.project_name}-ecs-task-sg-${var.environment}"
  description = "ECS tasks security group"
  vpc_id      = aws_vpc.main_b.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound to Account A CIDR (RDS)
  egress {
    from_port   = var.rds_port_a
    to_port     = var.rds_port_a
    protocol    = "tcp"
    cidr_blocks = [var.cidr_account_a]
    description = "Allow ECS to reach RDS in Account A"
  }

  tags = {
    Name = "${var.project_name}-ecs-task-sg-${var.environment}"
  }
}

# ═══════════════════════════════════════════════════════════════════════════
# Application Load Balancer
# ═══════════════════════════════════════════════════════════════════════════
resource "aws_lb" "backend" {
  provider           = aws.account_b
  idle_timeout       = 300
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public_b[*].id
}

resource "aws_lb_target_group" "backend" {
  provider    = aws.account_b
  name        = "${var.project_name}-tg-${var.environment}"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_b.id
  target_type = "ip"

  health_check {
    path                = var.health_check_path
    port                = var.container_port
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200,302"
  }
}

resource "aws_lb_listener" "backend" {
  provider          = aws.account_b
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# ═══════════════════════════════════════════════════════════════════════════
# ECS Task Definition
# ═══════════════════════════════════════════════════════════════════════════
resource "aws_ecs_task_definition" "backend" {
  provider                 = aws.account_b
  family                   = "${var.project_name}-backend-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "backend"
    image     = "${aws_ecr_repository.backend.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]
    environment = [
      { name = "APP_ENV", value = var.environment },
      { name = "DATABASE_URL", value = var.database_url },
      { name = "CORS_ORIGINS", value = var.cors_origins },
      { "name" : "COGNITO_REGION", "value" : var.cognito_region },
      { "name" : "COGNITO_USER_POOL_ID", "value" : var.cognito_user_pool_id },
      { "name" : "COGNITO_CLIENT_ID", "value" : var.cognito_client_id },
      { "name" : "GOOGLE_API_KEY", "value" : "arn:aws:secretsmanager:us-east-1:878581768959:secret:GOOGLE_API_KEY-wQtItx" },
      #{ "name" : "GEMINI_API_KEY", "value" : "arn:aws:secretsmanager:us-east-1:878581768959:secret:GEMINI_API_KEY-BuRN0G" },
      { "name" : "LAMBDA_URL", "value" : "arn:aws:secretsmanager:us-east-1:878581768959:secret:LAMBDA_URL-AEuOlS" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.backend.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# ═══════════════════════════════════════════════════════════════════════════
# ECS Service
# ═══════════════════════════════════════════════════════════════════════════
resource "aws_ecs_service" "backend" {
  provider        = aws.account_b
  name            = "${var.project_name}-backend-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.private_b[*].id
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = var.container_port
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
}