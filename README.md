# Terraform AWS EC2 with .NET Web API

This project provisions an AWS EC2 instance using Terraform and deploys a simple .NET Web API application.

## Overview

The infrastructure includes:
- AWS EC2 instance (t2.micro) running Amazon Linux
- Security group allowing HTTP traffic on port 8080 and SSH on port 22
- SSH key pair for secure access
- Automated deployment of a .NET 10 Web API

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- SSH client (built-in on Linux/Mac, or use PuTTY/OpenSSH on Windows)
- AWS S3 bucket for Terraform state storage: `tfplay-terraform-state-bucket`

## Setup Instructions

### 1. AWS Configuration

Ensure your AWS credentials are configured:
```bash
aws configure
```

### 2. Generate SSH Key Pair (if not already present)

If you don't have the SSH key pair, generate it:
```bash
ssh-keygen -t rsa -b 4096 -f ec2-key -N ""
```

This creates two files:
- `ec2-key` (private key) - **Keep this secure!**
- `ec2-key.pub` (public key)

### 3. Initialize Terraform

```bash
terraform init
```

This will:
- Download required AWS provider plugins
- Configure the S3 backend for state storage

### 4. Review the Plan

```bash
terraform plan
```

### 5. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm. This will:
- Create an SSH key pair in AWS
- Create a security group
- Launch an EC2 instance
- Deploy the .NET Web API
- Start the application on port 8080

### 6. Get the EC2 Public IP

After successful deployment, Terraform will output the public IP address:
```bash
terraform output public_ip
```

## Connecting via SSH

### Option 1: Using the SSH command (Linux/Mac/Windows with OpenSSH)

```bash
ssh -i ec2-key ec2-user@<PUBLIC_IP>
```

Replace `<PUBLIC_IP>` with the IP address from the Terraform output.

**Example:**
```bash
ssh -i ec2-key ec2-user@3.120.45.67
```

### Option 2: Using PowerShell (Windows)

```powershell
ssh -i ec2-key ec2-user@$(terraform output -raw public_ip)
```

### Option 3: Using PuTTY (Windows)

1. **Convert the private key to PuTTY format:**
   - Open PuTTYgen
   - Click "Load" and select the `ec2-key` file
   - Click "Save private key" and save as `ec2-key.ppk`

2. **Connect using PuTTY:**
   - Host Name: `ec2-user@<PUBLIC_IP>`
   - Connection > SSH > Auth > Credentials: Browse and select `ec2-key.ppk`
   - Click "Open"

### Troubleshooting SSH Connection

If you get a "Permission denied" error, ensure the private key has correct permissions:

**On Linux/Mac:**
```bash
chmod 400 ec2-key
```

**On Windows (PowerShell as Administrator):**
```powershell
icacls ec2-key /inheritance:r
icacls ec2-key /grant:r "$($env:USERNAME):(R)"
```

## Accessing the Web API

Once the instance is running, access the Web API:

```bash
# Health check
curl http://<PUBLIC_IP>:8080/health

# Root endpoint
curl http://<PUBLIC_IP>:8080/

# Sample data endpoint
curl http://<PUBLIC_IP>:8080/api/data
```

Or open in a browser: `http://<PUBLIC_IP>:8080`

## Project Structure

```
.
├── main.tf              # Main infrastructure configuration
├── variables.tf         # Variable definitions
├── outputs.tf           # Output values (e.g., public IP)
├── terraform.tf         # Terraform and provider settings
├── ec2-key              # Private SSH key (DO NOT COMMIT TO GIT)
├── ec2-key.pub          # Public SSH key
├── Program.cs           # .NET Web API application
├── webapi.csproj        # .NET project file
└── README.md            # This file
```

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `http_port` | HTTP port for the web server | 8080 |
| `db_username` | Database administrator username | dbadmin |
| `db_password` | Database administrator password | (required) |

## Checking Application Logs

After SSH-ing into the instance, view the application logs:

```bash
# View the application log
sudo cat /var/log/webapi.log

# Check if the application is running
ps aux | grep dotnet

# Check the port is listening
sudo netstat -tuln | grep 8080
```

## Cleanup

To destroy all resources and avoid AWS charges:

```bash
terraform destroy
```

Type `yes` when prompted to confirm.

## Security Notes

⚠️ **Important Security Considerations:**

1. **SSH Key:** Never commit `ec2-key` (private key) to version control. Add it to `.gitignore`.
2. **Security Group:** The current configuration allows SSH and HTTP from any IP (`0.0.0.0/0`). For production, restrict to specific IP ranges.
3. **Sensitive Variables:** Use environment variables or AWS Secrets Manager for sensitive data like `db_password`.

## Region

This project is configured for the `eu-central-1` (Frankfurt) region. To change regions, modify the `region` parameter in [main.tf](main.tf).

## Support

For issues or questions:
1. Check Terraform logs: `terraform apply` with verbose output
2. Check AWS Console for resource status
3. SSH into the instance and check application logs

## License

This project is for demonstration purposes.
