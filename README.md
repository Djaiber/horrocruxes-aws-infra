# Horrocruxes AWS Infrastructure

Terraform configuration for the Horrocruxes project — a cross-account Harry Potter question-answering system.
Resources are deployed across **two AWS accounts**:

---

## Related Repositories

This repo is part of a multi-repo project. Here's the full picture:

| Repository | Description | Link |
|---|---|---|
| **horrocruxes-aws-infra** (this repo) | Terraform — AWS infrastructure (VPC, ECS, RDS, ALB, VPC Peering) | Current repository |
| **devops_backend_horrocrux** | Python backend service deployed on ECS Fargate | [github.com/Djaiber/devops_backend_horrocrux](https://github.com/Djaiber/devops_backend_horrocrux.git) |
| **horrocruxes-epam** | Lambda + LangGraph logic for AI question-answering | [github.com/JevDev2304/horrocruxes-epam](https://github.com/JevDev2304/horrocruxes-epam.git) |
| **horrocruxes-front-platform** | Frontend deployed via Ansible | [github.com/JevDev2304/horrocruxes-front-platform](https://github.com/JevDev2304/horrocruxes-front-platform.git) |

- **Account A** : Existing RDS PostgreSQL database (private, no public IP)
- **Account B** : ECS Fargate, ALB, VPC, VPC Peering, CloudFront Distribution
- **Account C** : Lambda Core (Langgraph)

---

## Architecture

```
Account B (ECS/ALB)                  VPC Peering                Account A (RDS)
┌──────────────────────────┐    <peering-connection-id>    ┌─────────────────────┐
│  VPC <account-b-vpc-cidr>│ ◄────────────────────────────►│  VPC <acct-a-cidr>  │
│  ├─ Public subnets (ALB) │                               │  └─ RDS (private)   │
│  └─ Private subnets      │                               │     port 5432       │
│     └─ Fargate tasks     │                               └─────────────────────┘
└──────────────────────────┘
          │
     Internet (HTTPS)
     ALB + ACM Certificate
```

**Key design decisions:**
- RDS is **not publicly accessible** — reachable only via VPC peering from Account B
- ECS tasks connect to RDS using the private endpoint
- HTTPS is terminated at the ALB using an ACM certificate
- NAT Gateway lives in Account B (Account A has no NAT)

---

## Prerequisites

- **Terraform** >= 1.6.0
- **AWS CLI** configured with two profiles (`account_a`, `account_b`)
- **IAM permissions** to create resources in both accounts
- **Existing RDS** in Account A (imported via Terraform — see below)

---

## Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/Djaiber/horrocruxes-aws-infra.git
   cd horrocruxes-aws-infra
   ```

2. **Configure AWS profiles**
   ```bash
   aws configure --profile account_a   # Account A (RDS)
   aws configure --profile account_b   # Account B (ECS/ALB)
   ```

3. **Create terraform.tfvars**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit with your account IDs, CIDRs, database credentials, etc.
   ```

4. **Initialize Terraform**
   ```bash
   terraform init
   ```

---

## Importing Existing Resources

Several resources already exist in AWS and must be imported before running `apply`.
Run these commands **before** `terraform plan`.

> ⚠️ Replace all `<placeholders>` with your actual values from the AWS Console or CLI before running.

### Account A (RDS side)

| Resource | Import command |
|---|---|
| VPC | `terraform import aws_vpc.main_a <account-a-vpc-id>` |
| RDS instance | `terraform import aws_db_instance.postgresql <db-instance-identifier>` |
| DB subnet group | `terraform import aws_db_subnet_group.rds <db-subnet-group-name>` |
| Security group (RDS) | `terraform import aws_security_group.rds <rds-security-group-id>` |
| Route table | `terraform import aws_route_table.private_a <route-table-id>` |

### Account B (compute side)

| Resource | Import command |
|---|---|
| ALB HTTP listener | `terraform import aws_lb_listener.http arn:aws:elasticloadbalancing:<region>:<account-id-b>:listener/app/<alb-name>/<alb-id>/<http-listener-id>` |
| ALB HTTPS listener | `terraform import aws_lb_listener.https arn:aws:elasticloadbalancing:<region>:<account-id-b>:listener/app/<alb-name>/<alb-id>/<https-listener-id>` |

> After importing, run `terraform plan` to verify there are no unexpected changes before applying.

---

## File Structure

```
├── alb.tf              # ALB, target group, listeners (HTTP + HTTPS), ALB security group
├── ecs.tf              # ECR, ECS cluster, task definition, service, IAM roles
├── outputs.tf          # Useful outputs (ALB DNS, ECR URL, ECS cluster, etc.)
├── providers.tf        # AWS provider aliases for both accounts
├── variables.tf        # All input variables
├── terraform.tfvars    # Variable values (git-ignored)
├── vpc-b.tf            # VPC in Account B, subnets, NAT gateway
└── vpc-peering.tf      # Cross-account VPC peering and route tables
```

---

## Deployment

1. **Import existing resources** (see above)

2. **Plan**
   ```bash
   terraform plan -var-file="terraform.tfvars" -out=tfplan
   ```

3. **Apply**
   ```bash
   terraform apply tfplan
   ```

4. **Verify**
   ```bash
   terraform output alb_dns_name
   curl https://<alb-dns>/api/health
   ```

---

## Connecting to RDS (Private Access Only)

RDS has no public IP. To connect directly for debugging, use ECS Exec into a running Fargate task:

```bash
# Get the running task ID
TASK_ID=$(aws ecs list-tasks \
  --cluster <ecs-cluster-name> \
  --region <region> \
  --query 'taskArns[0]' \
  --output text | cut -d'/' -f3)

# Exec into the container
aws ecs execute-command \
  --cluster <ecs-cluster-name> \
  --task $TASK_ID \
  --container backend \
  --interactive \
  --command "/bin/sh" \
  --region <region>

# Test connectivity from inside the container
python3 -c "
import socket
s = socket.create_connection(('<rds-endpoint>', 5432), timeout=5)
print('RDS reachable!')
s.close()
"
```

> ECS Exec requires `enable_execute_command = true` on the ECS service and `ssmmessages:*` permissions on the ECS task role — both already configured.

---

## Outputs

| Output | Description |
|---|---|
| `alb_dns_name` | ALB endpoint for the ECS service |
| `ecr_repository_url` | ECR repository URL for backend Docker images |
| `ecs_cluster_name` | ECS cluster name |
| `ecs_service_name` | ECS service name |
| `vpc_peering_id` | VPC peering connection ID |

---

## Cleanup

```bash
terraform destroy -var-file="terraform.tfvars"
```

> ⚠️ This destroys all resources in **Account B** only. The RDS instance in Account A is managed separately and remains untouched.

---

## Important Notes

- The RDS security group in Account A allows inbound PostgreSQL (`5432`) from Account B's VPC CIDR only
- The ECS task role has `secretsmanager:GetSecretValue` for API keys stored in Secrets Manager
- The HTTPS listener uses an ACM certificate for the project domain
- Terraform state is stored locally — consider migrating to S3 + DynamoDB for team use
- The CloudFront distribution and S3 frontend are managed in a separate repository (not included here YET)
