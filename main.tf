terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

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
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    echo "Listen ${var.http_port}" >> /etc/httpd/conf/httpd.conf
    echo "hi there" > /var/www/html/index.html
    systemctl start httpd
    systemctl enable httpd
    EOF
}