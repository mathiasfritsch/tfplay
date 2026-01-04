provider "aws" {
  region = "eu-central-1"
}

# Get the latest Amazon Linux 2023 AMI from AWS Systems Manager Parameter Store
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# IAM role for EC2 to access RDS with IAM authentication
resource "aws_iam_role" "ec2_rds_role" {
  name = "ec2-rds-iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ec2-rds-iam-role"
  }
}

# IAM policy for RDS IAM authentication
resource "aws_iam_role_policy" "rds_iam_auth" {
  name = "rds-iam-auth-policy"
  role = aws_iam_role.ec2_rds_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = [
          "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.postgres.resource_id}/${var.db_username}"
        ]
      }
    ]
  })
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-rds-instance-profile"
  role = aws_iam_role.ec2_rds_role.name
}

# Get current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-key"
  public_key = file("${path.module}/ec2-key.pub")
}

resource "aws_security_group" "web_server" {
  name        = "web-server-sg"
  description = "Allow inbound traffic on port ${var.http_port}"

  ingress {
    description = "HTTP on ${var.http_port}"
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-sg"
  }
}

resource "aws_instance" "example" {
  ami           = data.aws_ssm_parameter.al2023_ami.value
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.web_server.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  
  tags = {
    Name ="someserver"
  }
  
  provisioner "file" {
    source      = "${path.module}/Program.cs"
    destination = "/tmp/Program.cs"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${path.module}/ec2-key")
      host        = self.public_ip
    }
  }
  
  provisioner "file" {
    source      = "${path.module}/webapi.csproj"
    destination = "/tmp/webapi.csproj"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${path.module}/ec2-key")
      host        = self.public_ip
    }
  }
  
  provisioner "file" {
    source      = "${path.module}/init-db.sql"
    destination = "/tmp/init-db.sql"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${path.module}/ec2-key")
      host        = self.public_ip
    }
  }
  
  user_data = <<-EOF
    #!/bin/bash
    # Install .NET 9 SDK and PostgreSQL client
    sudo dnf install -y dotnet-sdk-9.0 postgresql15
    
    # Wait for files to be provisioned
    sleep 10
    
    # Wait for RDS to be available
    sleep 60
    
    # Create app directory
    mkdir -p /home/ec2-user/webapi
    cp /tmp/Program.cs /home/ec2-user/webapi/
    cp /tmp/webapi.csproj /home/ec2-user/webapi/
    chown -R ec2-user:ec2-user /home/ec2-user/webapi
    
    # Set environment variables for database connection
    export DB_HOST="${aws_db_instance.postgres.address}"
    export DB_NAME="${aws_db_instance.postgres.db_name}"
    export DB_USER="${var.db_username}"
    export AWS_REGION="eu-central-1"
    echo "export DB_HOST=\"$DB_HOST\"" >> /home/ec2-user/.bashrc
    echo "export DB_NAME=\"$DB_NAME\"" >> /home/ec2-user/.bashrc
    echo "export DB_USER=\"$DB_USER\"" >> /home/ec2-user/.bashrc
    echo "export AWS_REGION=\"$AWS_REGION\"" >> /home/ec2-user/.bashrc
    
    # Initialize database (using password for initial setup)
    PGPASSWORD="${var.db_password}" psql -h ${aws_db_instance.postgres.address} -U ${var.db_username} -d ${aws_db_instance.postgres.db_name} -f /tmp/init-db.sql
    
    # Grant rds_iam role to the database user
    PGPASSWORD="${var.db_password}" psql -h ${aws_db_instance.postgres.address} -U ${var.db_username} -d ${aws_db_instance.postgres.db_name} -c "GRANT rds_iam TO ${var.db_username};"
    
    # Build and run the app
    cd /home/ec2-user/webapi
    sudo -u ec2-user dotnet build
    sudo touch /var/log/webapi.log
    sudo chown ec2-user:ec2-user /var/log/webapi.log
    sudo -u ec2-user bash -c "DB_HOST='$DB_HOST' DB_NAME='$DB_NAME' DB_USER='$DB_USER' AWS_REGION='$AWS_REGION' nohup dotnet run > /var/log/webapi.log 2>&1 &"
    EOF
}

data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "db_subnet_1" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.128.0/20"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "db-subnet-1"
  }
}

resource "aws_subnet" "db_subnet_2" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.144.0/20"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "db-subnet-2"
  }
}

resource "aws_db_subnet_group" "postgres" {
   name       = "postgres-subnet-group"
   subnet_ids = [aws_subnet.db_subnet_1.id, aws_subnet.db_subnet_2.id]

   tags = {
     Name = "postgres-subnet-group"
   }
 }

 resource "aws_security_group" "rds" {
   name        = "rds-postgres-sg"
   description = "Allow PostgreSQL traffic from web server"

   ingress {
     description     = "PostgreSQL from web server"
     from_port       = 5432
     to_port         = 5432
     protocol        = "tcp"
     security_groups = [aws_security_group.web_server.id]
   }

   egress {
     from_port   = 0
     to_port     = 0
     protocol    = "-1"
     cidr_blocks = ["0.0.0.0/0"]
   }

   tags = {
     Name = "rds-postgres-sg"
   }
 }

 resource "aws_db_instance" "postgres" {
   identifier           = "postgres-db"
   engine              = "postgres"
   engine_version      = "16"
   instance_class      = "db.t3.micro"
   allocated_storage   = 20
   storage_type        = "gp2"
  
   db_name             = "catalogdb"
   username            = var.db_username
   password            = var.db_password
   
   iam_database_authentication_enabled = true
  
   db_subnet_group_name   = aws_db_subnet_group.postgres.name
   vpc_security_group_ids = [aws_security_group.rds.id]
   publicly_accessible    = true
   skip_final_snapshot    = true
  
   tags = {
     Name = "postgres-db"
   }
 }