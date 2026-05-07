# alb.tf
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
# ═══════════════════════════════════════════════════════════════════════════
# ALB Listeners
# ═══════════════════════════════════════════════════════════════════════════
resource "aws_lb_listener" "http" {
  provider          = aws.account_b
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
  tags = {
    Name = "${var.project_name}-alb-sg-${var.environment}"
  }
}

resource "aws_lb_listener" "https" {
  provider          = aws.account_b
  load_balancer_arn = aws_lb.backend.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:878581768959:certificate/ef9b8983-6a01-4756-b1b7-da5fd303923e"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
  tags = {
    Name = "${var.project_name}-alb-sg-${var.environment}"
  }
}