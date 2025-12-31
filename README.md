# Terraform AWS Web Server with Auto Scaling and Load Balancer

This Terraform configuration creates a highly available, scalable web server infrastructure on AWS with an Application Load Balancer.

## Architecture Diagram

```
                                    Internet
                                       │
                                       │ (HTTP:80)
                                       ▼
                            ┌──────────────────────┐
                            │  Application Load    │
                            │     Balancer         │
                            │   (alb-sg)           │
                            └──────────────────────┘
                                       │
                        ┌──────────────┼──────────────┐
                        │              │              │
                        ▼              ▼              ▼
                ┌───────────────┬───────────────┬───────────────┐
                │  Subnet 1     │  Subnet 2     │  Subnet 3     │
                │  (eu-c-1a)    │  (eu-c-1b)    │  (eu-c-1c)    │
                └───────────────┴───────────────┴───────────────┘
                        │              │              │
                        │    Target Group (8080)      │
                        │              │              │
                ┌───────┴──────────────┴──────────────┴────────┐
                │      Auto Scaling Group (2-4 instances)      │
                │              (web-server-sg)                 │
                └──────────────────────────────────────────────┘
                        │              │
                        ▼              ▼
                  ┌──────────┐   ┌──────────┐
                  │ EC2 t2   │   │ EC2 t2   │
                  │ micro    │   │ micro    │
                  │ :8080    │   │ :8080    │
                  └──────────┘   └──────────┘
```

## Resources Created

### 1. ALB Security Group (`aws_security_group.alb`)
- **Name**: `alb-sg`
- **Purpose**: Controls network access to the Application Load Balancer
- **Inbound Rules**: Allows HTTP traffic on port 80 from anywhere (0.0.0.0/0)
- **Outbound Rules**: Allows all outbound traffic

### 2. Web Server Security Group (`aws_security_group.web_server`)
- **Name**: `web-server-sg`
- **Purpose**: Controls network access to the web servers
- **Inbound Rules**: Allows HTTP traffic on port 8080 from ALB security group only
- **Outbound Rules**: Allows all outbound traffic

### 3. Additional Subnets (`aws_subnet.additional_1`, `aws_subnet.additional_2`)
- **Purpose**: Ensures multi-AZ deployment for high availability
- **CIDR Blocks**: 172.31.48.0/20 and 172.31.64.0/20
- **Availability Zones**: Distributed across eu-central-1a, eu-central-1b, eu-central-1c
- **Public IPs**: Enabled for NAT gateway compatibility

### 4. Launch Template (`aws_launch_template.web_server`)
- **AMI**: Amazon Linux 2 (ami-0f2367292005b3bad)
- **Instance Type**: t2.micro (Free Tier eligible)
- **User Data**: Installs and configures Apache httpd to listen on port 8080
- **Lifecycle**: `create_before_destroy = true` ensures new template is created before old one is destroyed

### 5. Target Group (`aws_lb_target_group.web_server`)
- **Name**: `web-server-tg`
- **Port**: 8080
- **Protocol**: HTTP
- **Health Check**: 
  - Path: `/`
  - Interval: 30 seconds
  - Healthy threshold: 2
  - Unhealthy threshold: 2
  - Timeout: 5 seconds

### 6. Application Load Balancer (`aws_lb.web_server`)
- **Name**: `web-server-alb`
- **Type**: Application Load Balancer
- **Scheme**: Internet-facing
- **Subnets**: Deployed across 3 availability zones
- **Security**: Protected by ALB security group

### 7. Load Balancer Listener (`aws_lb_listener.web_server`)
- **Port**: 80
- **Protocol**: HTTP
- **Action**: Forwards traffic to target group on port 8080

### 8. Auto Scaling Group (`aws_autoscaling_group.web_server`)
- **Name**: `web-server-asg`
- **Min Size**: 2 instances
- **Max Size**: 4 instances
- **Desired Capacity**: 2 instances
- **Deployment**: Instances distributed across 3 availability zones
- **Health Check**: ELB health checks with 300 second grace period
- **Target Group**: Automatically registers/deregisters instances
- **Lifecycle**: `create_before_destroy = true` enables zero-downtime updates

### 9. Data Sources
- **aws_vpc.default**: Retrieves the default VPC
- **aws_availability_zones.available**: Gets available AZs in the region
- **aws_subnets.default**: Retrieves default subnets in the VPC

## Configuration

### Variables (variables.tf)
- `http_port`: HTTP port for the web server (default: 8080)

### Outputs (outputs.tf)
- `asg_name`: Name of the Auto Scaling Group
- `alb_dns_name`: DNS name of the Application Load Balancer (use this to access your application)

## Web Server Details

Each instance runs Apache httpd configured to:
- Listen on port 8080 (configurable via `http_port` variable)
- Serve "hi there" from `/var/www/html/index.html`
- Start automatically on boot
- Report health status to the load balancer

## Usage

### Deploy the infrastructure
```bash
terraform init
terraform plan
terraform apply
```

### Change the HTTP port
```bash
terraform apply -var="http_port=80"
```

### View outputs
```bash
terraform output
```

### Get the ALB URL
```bash
terraform output alb_dns_name
```

### Destroy the infrastructure
```bash
terraform destroy
```

## Access

Once deployed, access the web application through the Application Load Balancer:

1. Get the ALB DNS name: `terraform output alb_dns_name`
2. Access via: `http://<alb-dns-name>`

The load balancer will automatically distribute traffic across healthy instances in multiple availability zones.

**Note**: Instances are not directly accessible from the internet. All traffic must go through the ALB on port 80, which then routes to instances on port 8080.

## Requirements

- Terraform >= 1.0.0, < 2.0.0
- AWS Provider ~> 5.0
- AWS credentials configured (default profile with eu-central-1 region)


## Next task: create a keypair for acessing the instances and add some logging