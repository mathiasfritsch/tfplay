terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "http_port" {
  description = "HTTP port for the web server"
  type        = number
  default     = 8080
}

provider "aws" {
  region = "eu-central-1"
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

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.example.public_ip
}