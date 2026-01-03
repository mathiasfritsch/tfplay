provider "aws" {
  region = "eu-central-1"
}

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
  ami           = "ami-0f2367292005b3bad"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.web_server.id]
  
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
  
  user_data = <<-EOF
    #!/bin/bash
    # Install .NET 10 SDK
    sudo rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm
    sudo yum install -y dotnet-sdk-10.0
    
    # Wait for files to be provisioned
    sleep 10
    
    # Create app directory
    mkdir -p /home/ec2-user/webapi
    cp /tmp/Program.cs /home/ec2-user/webapi/
    cp /tmp/webapi.csproj /home/ec2-user/webapi/
    chown -R ec2-user:ec2-user /home/ec2-user/webapi
    
    # Build and run the app
    cd /home/ec2-user/webapi
    sudo -u ec2-user dotnet build
    sudo -u ec2-user nohup dotnet run > /var/log/webapi.log 2>&1 &
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
  
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true
  skip_final_snapshot    = true
  
  tags = {
    Name = "postgres-db"
  }
}