locals {
  environment = "sbx"
  subnet_id_a = "subnet-019d987336a8de47f"
  subnet_id_b = "subnet-0835490e803eefcb1"
}

# Data for Retrieve Subnet and VPC 

data "aws_subnet" "subnet_id" {
  id = local.subnet_id_a
}

# Creating Security group for RDS MySQL DB 

resource "aws_security_group" "sg_rds_db" {
  name   = "sg_rds_db"
  vpc_id = data.aws_subnet.subnet_id.vpc_id

  ingress { # Pick an adecuate values for each ingress, in this case is TCP for MySQL
    description = "MySQL access"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"] # Pick an adecuate values for each ingress, in this case is all Private from IPv4
  }

  ingress { # Pick an adecuate values for each ingress, in this case is icmp
    description = "Allow all traffic ICMP access from Private Networks"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"] # Pick an adecuate values for each ingress, in this case is all Private from IPv4
  }

  egress { # Pick an adecuate values for each egress, in this case is ALL IPv4
    description = "Allow all traffic output to Private Networks"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating a random password

resource "random_password" "password" {
  length           = 16
  override_special = "!#$%^&*()-_=+[]{}<>:?" # Overriding these special characters
  special          = true                    # Special characters needed
}

# Creating an AWS Secret for store the random password

resource "aws_secretsmanager_secret" "db-pass" {
  name = "db-sorter-sp10-pass"
}

# Storing the random passwor in the AWS Secret

resource "aws_secretsmanager_secret_version" "db-pass-val" {
  secret_id     = aws_secretsmanager_secret.db-pass.id # Value Taken from resource aws_secretsmanager_secret.db-pass
  secret_string = random_password.password.result      # Value Taken from resource random_password.password
}

# Retrieving Secret Version ID

data "aws_secretsmanager_secret_version" "db-pass-val" {
  secret_id = aws_secretsmanager_secret.db-pass.id

  depends_on = [
    aws_secretsmanager_secret.db-pass
  ]
}

# RDS DB Subnet Group

resource "aws_db_subnet_group" "default_mysql8" {
  name        = "default_mysql8"
  description = "default db subnet group mysql8 for subnets ${local.subnet_id_a} and ${local.subnet_id_b}"
  subnet_ids  = [local.subnet_id_a, local.subnet_id_b]

  tags = {
    Name = "default subnet group"
  }
}

# Creating a MySQL RDS DB

resource "aws_db_instance" "sa-db-sorter-damon-sp10" {
  allocated_storage           = 20                                                               # Pick an adecuate value
  max_allocated_storage       = 1000                                                             # Pick an adecuate value
  storage_type                = "gp2"                                                            # Pick an adecuate value
  engine                      = "mysql"                                                          # Pick an adecuate value
  engine_version              = "8.0.34"                                                         # Pick an adecuate value
  instance_class              = "db.t3.micro"                                                    # Pick an adecuate value
  identifier                  = "sa-db-sorter-damon-sp10"                                        # Pick an adecuate value
  db_name                     = "sa_db_sorter_damon_sp10"                                        # Pick an adecuate value
  username                    = "dbsorteradmin"                                                  # Pick an adecuate value
  password                    = data.aws_secretsmanager_secret_version.db-pass-val.secret_string # Taken from value storage in resource aws_secretsmanager_secret_version.db-pass-val
  parameter_group_name        = "default.mysql8.0"                                               # Copy the parameter_group_name from the RDS Console
  db_subnet_group_name        = aws_db_subnet_group.default_mysql8.id                            # Copy the subnet group from the RDS Console
  vpc_security_group_ids      = [aws_security_group.sg_rds_db.id]                                # Taken from resource aws_security_group.sg_rds_db.id
  skip_final_snapshot         = local.environment == "prd" ? false : true
  storage_encrypted           = true
  publicly_accessible         = false # Pick an adecuate value
  multi_az                    = local.environment == "prd" ? true : false
  allow_major_version_upgrade = local.environment == "prd" ? false : true
  deletion_protection         = local.environment == "prd" ? true : false
  apply_immediately           = local.environment == "prd" ? false : true

  tags = { # Pick adecuate values
    Name            = "sa-db-sorter-damon-sp10"
    confidentiality = "internal"
    integrity       = "moderate"
    availability    = "moderate"
  }
}
