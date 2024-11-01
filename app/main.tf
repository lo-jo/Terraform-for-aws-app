terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

# PROVIDER 
provider "aws" {
  region = "eu-west-3"
}

# Key Pair
#resource "aws_key_pair" "app_key_pair" {
#  key_name   = "ssh_key"
#  public_key = file("~/.ssh/pub_aws.pem")
#}


# Local var for current caller 
data "aws_caller_identity" "current" {}


#################### RESOURCES #####################
# ami Amazon Linux 2
resource "aws_instance" "app_server" {
  ami                    = "ami-04a790ca5ad2f097c"
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.test_profile.name
#  key_name               = aws_key_pair.app_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.app_server_sg.id]

  user_data = <<-EOF
            #!/bin/bash
            sudo yum update -y
            sudo amazon-linux-extras install nginx1 -y
            sudo systemctl start nginx
            sudo systemctl enable nginx
            EOF

  tags = {
    Name = "ExampleAppServerInstance"
  }
}

locals {
  app_server_ip = aws_instance.app_server.public_ip
}

# IAM role 
resource "aws_iam_role" "database_role" {
  name = "database_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = aws_iam_role.database_role.name
}

# minimal access to db
resource "aws_iam_role_policy" "rds_access_policy" {
  name = "rds_access_policy"
  role = aws_iam_role.database_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "rds-db:connect",
      "Resource": "arn:aws:rds-db:eu-west-3:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.my_postgres_db.id}/${var.db_username}"
    }
  ]
}
EOF
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "postgresql access from within the instance"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_server_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDSSecurityGroup"
  }
}



resource "aws_security_group" "app_server_sg" {
  name        = "app-server-sg"
  description = "Allow SSH and HTTP traffic"

  # HTTP access for NGINX (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

#  ingress {
#    from_port   = 22
#    to_port     = 22
#    protocol    = "tcp"
#    cidr_blocks = ["0.0.0.0/0"]
#  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AppServerSecurityGroup"
  }
}


# RDS INSTANCE PostgreSQL
resource "aws_db_instance" "my_postgres_db" {
  identifier          = "my-postgres-instance"
  engine              = "postgres"
  engine_version      = "13"
  instance_class      = "db.t3.micro"
  allocated_storage   = 5
  username            = var.db_username
  password            = var.db_pw
  db_name             = var.db_name
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  tags = {
    Name = "MyPostgresDB"
  }
}

#output "rds_endpoint" {
#  value = aws_db_instance.my_postgres_db.endpoint
#}

output "app_server_public_ip" {
  description = "public IP address of the app"
  value       = aws_instance.app_server.public_ip
}