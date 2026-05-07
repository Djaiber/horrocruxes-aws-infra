variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
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
  default     = "854198083295"
}

variable "account_id_b" {
  description = "Account B - ECS, ALB, CloudFront"
  type        = string
  default     = "878581768959"
}

# ── VPC CIDRs ────────────────────────────────────────────────────────────
variable "cidr_account_a" {
  description = "CIDR block of existing VPC in Account A"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cidr_account_b" {
  description = "CIDR block for new VPC in Account B"
  type        = string
  # Must not overlap with Account A (10.0.0.0/16)
  default = "172.16.0.0/16" # ← Changed to avoid overlap
}

# ── VPC B Subnets ────────────────────────────────────────────────────────
variable "public_subnet_cidrs_b" {
  type    = list(string)
  default = ["172.16.1.0/24", "172.16.2.0/24"]
}

variable "private_subnet_cidrs_b" {
  type    = list(string)
  default = ["172.16.10.0/24", "172.16.11.0/24"]
}

# ── Existing Resources in Account A ───────────────────────────────────────
variable "vpc_id_a" {
  description = "Existing VPC ID in Account A"
  type        = string
  default     = "vpc-0457b1b6c2eb038b7"
}

variable "rds_endpoint_a" {
  description = "RDS endpoint in Account A"
  type        = string
  default     = "harrypotter-db-dev-q5qjx558.ckd83boidbuw.us-east-1.rds.amazonaws.com"
}

variable "rds_port_a" {
  type    = number
  default = 5432
}

# ── Route Table IDs in Account A (for return route) ──────────────────────
variable "private_route_table_ids_a" {
  description = "Private route table IDs in Account A (add return route)"
  type        = list(string)
  # Update with actual route table IDs from Account A
  default = ["rtb-01a3e00bbaf1099f6"]
}

# ── ECS/ALB Configuration ────────────────────────────────────────────────
variable "container_port" {
  type    = number
  default = 8080
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
  default   = "postgresql://user_harry:Pasword123#@harrypotter-db-dev-q5qjx558.ckd83boidbuw.us-east-1.rds.amazonaws.com:5432/harrypotter_db"
}

#--- ECS task environment variables------
variable "cors_origins" {
  type    = string
  default = "http://localhost:4200,http://localhost:3000,https://www.horrocruxes-harrypotter-rag.me,https://horrocruxes-harrypotter-rag.me"
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