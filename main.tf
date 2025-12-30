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

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_launch_template" "web_server" {
  name_prefix   = "web-server-"
  image_id      = "ami-0f2367292005b3bad"
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.web_server.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    echo "Listen ${var.http_port}" >> /etc/httpd/conf/httpd.conf
    echo "hi there" > /var/www/html/index.html
    systemctl start httpd
    systemctl enable httpd
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "asg-web-server"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web_server" {
  name                = "web-server-asg"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.web_server.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "asg-web-server"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}