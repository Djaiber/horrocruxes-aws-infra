# Account B (main deployment account)
provider "aws" {
  alias  = "account_b"
  region = var.aws_region
  assume_role {
    role_arn = "arn:aws:iam::${var.account_id_b}:role/admin-role-account-b"
  }
}


# Account A (RDS account) - for peering request
provider "aws" {
  alias  = "account_a"
  region = var.aws_region
  assume_role {
    role_arn = "arn:aws:iam::${var.account_id_a}:role/admin-role-account-a"
  }
}