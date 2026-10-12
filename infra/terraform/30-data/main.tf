# 30-data — PostgreSQL and Secrets Manager, private and passwordless for the app.
#
# - The master password is generated and stored by RDS in Secrets Manager
#   (manage_master_user_password): it never appears in Terraform state.
# - The application connects with IAM database authentication (15-minute
#   tokens signed with its EKS Pod Identity credentials) — no password at all.
# - Secret VALUES (banner) are written out-of-band, never by Terraform.

locals {
  network = data.terraform_remote_state.network.outputs
  name    = "${var.org}-portal-${var.environment}"
}

resource "aws_security_group" "db" {
  name        = "sg-rds-${local.name}"
  description = "PostgreSQL from the EKS private subnets only"
  vpc_id      = local.network.vpc_id

  ingress {
    description = "PostgreSQL from pods/nodes (VPC CNI gives pods private-subnet IPs)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = local.network.private_subnet_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "portal" {
  identifier     = "rds-${local.name}"
  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = "portal"
  username                    = "mfsadmin"
  manage_master_user_password = true # password lives in Secrets Manager, rotated by RDS

  iam_database_authentication_enabled = true

  db_subnet_group_name   = local.network.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false # lab; production: true (or Aurora)

  backup_retention_period    = 1
  auto_minor_version_upgrade = true
  apply_immediately          = true
  deletion_protection        = false
  skip_final_snapshot        = true
}

# Container for the sample secret; the value is set with the CLI (lab 05).
resource "aws_secretsmanager_secret" "banner" {
  name                    = "${var.org}/portal/banner-${var.name_suffix}"
  description             = "Banner text shown by the customer portal (sample secret)"
  recovery_window_in_days = 0 # lab: allow immediate re-creation after the daily destroy
}

resource "aws_secretsmanager_secret" "datadog" {
  name                    = "${var.org}/datadog/api-key-${var.name_suffix}"
  description             = "Datadog API key (phase 12)"
  recovery_window_in_days = 0
}
