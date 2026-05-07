variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "project_name" {
  type    = string
  default = "horrocruxes"
}

variable "environment" {
  type    = string
  default = "dev"
}

# ── Account IDs ──────────────────────────────────────────────────────────
variable "account_id_a" {
  description = "Account A - RDS database"
  type        = string
}

variable "account_id_b" {
  description = "Account B - ECS, ALB, CloudFront"
  type        = string
}

# ── VPC CIDRs ────────────────────────────────────────────────────────────
variable "cidr_account_a" {
  description = "CIDR block of existing VPC in Account A"
  type        = string
 
}

variable "cidr_account_b" {
  description = "CIDR block for new VPC in Account B"
  type        = string
}

# ── VPC B Subnets ────────────────────────────────────────────────────────
variable "public_subnet_cidrs_b" {
  type    = list(string)
}

variable "private_subnet_cidrs_b" {
  type    = list(string)
}

# ── Existing Resources in Account A ───────────────────────────────────────
variable "vpc_id_a" {
  description = "Existing VPC ID in Account A"
  type        = string
}

variable "rds_endpoint_a" {
  description = "RDS endpoint in Account A"
  type        = string
}

variable "rds_port_a" {
  type    = number
}

# ── Route Table IDs in Account A (for return route) ──────────────────────
variable "private_route_table_ids_a" {
  description = "Private route table IDs in Account A (add return route)"
  type        = list(string)
}

# ── ECS/ALB Configuration ────────────────────────────────────────────────
variable "container_port" {
  type    = number
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "database_url" {
  type      = string
  sensitive = true
}

#--- ECS task environment variables------
variable "cors_origins" {
  type    = string
}
variable "cognito_region" {
  type    = string
  default = "us-east-1"
}
variable "cognito_user_pool_id" {
  type = string
}
variable "cognito_client_id" {
  type = string
}