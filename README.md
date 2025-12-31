# Terraform AWS Web Server with Auto Scaling

This Terraform configuration creates a scalable web server infrastructure on AWS.

## Resources Created

### 1. Security Group (`aws_security_group.web_server`)
- **Name**: `web-server-sg`
- **Purpose**: Controls network access to the web servers
- **Inbound Rules**: Allows HTTP traffic on port 8080 from anywhere (0.0.0.0/0)
- **Outbound Rules**: Allows all outbound traffic

### 2. Launch Template (`aws_launch_template.web_server`)
- **AMI**: Amazon Linux 2 (ami-0f2367292005b3bad)
- **Instance Type**: t2.micro (Free Tier eligible)
- **User Data**: Installs and configures Apache httpd to listen on port 8080
- **Lifecycle**: `create_before_destroy = true` ensures new template is created before old one is destroyed

### 3. Auto Scaling Group (`aws_autoscaling_group.web_server`)
- **Min Size**: 2 instances
- **Max Size**: 4 instances
- **Desired Capacity**: 2 instances
- **Deployment**: Instances are distributed across default VPC subnets
- **Lifecycle**: `create_before_destroy = true` enables zero-downtime updates

### 4. Data Sources
- **aws_vpc.default**: Retrieves the default VPC
- **aws_subnets.default**: Retrieves all subnets in the default VPC for instance distribution

## Configuration

### Variables (variables.tf)
- `http_port`: HTTP port for the web server (default: 8080)

### Outputs (outputs.tf)
- `asg_name`: Name of the Auto Scaling Group

## Web Server Details

Each instance runs Apache httpd configured to:
- Listen on port 8080 (configurable via `http_port` variable)
- Serve "hi there" from `/var/www/html/index.html`
- Start automatically on boot

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

### Destroy the infrastructure
```bash
terraform destroy
```

## Access

Once deployed, you can access the web servers on port 8080. To find the instance IPs:
1. Go to AWS EC2 Console
2. Look for instances tagged `asg-web-server`
3. Access via: `http://<instance-public-ip>:8080`

## Requirements

- Terraform >= 1.0.0, < 2.0.0
- AWS Provider ~> 5.0
- AWS credentials configured (default profile with eu-central-1 region)


## Next task: create a keypair for acessing the instances and add some logging