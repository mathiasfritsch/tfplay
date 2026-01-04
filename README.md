# Terraform AWS EC2 with .NET Web API

This project provisions an AWS EC2 instance using Terraform and deploys a simple .NET Web API application.

## Overview

The infrastructure includes:
- AWS EC2 instance (t2.micro) running Amazon Linux 2023
- AWS RDS PostgreSQL database (db.t3.micro) with products catalog
- IAM authentication for secure database access (no hardcoded passwords)
- IAM roles and policies for EC2 to RDS connectivity
- Security groups for web server and database access
- SSH key pair for secure access
- Automated deployment of a .NET 9 Web API with database connectivity
- Latest AMI automatically retrieved from AWS Systems Manager Parameter Store
- Database initialization with products table and sample data

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

# Get all products from database
curl http://<PUBLIC_IP>:8080/products

# Add a new product
curl -X POST http://<PUBLIC_IP>:8080/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Headphones"}'
```

Or open in a browser: `http://<PUBLIC_IP>:8080`

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Welcome message |
| `/health` | GET | Health check with timestamp |
| `/products` | GET | List all products from database |
| `/products` | POST | Add a new product (JSON body: `{"name": "Product Name"}`) |

## Project Structure

```
.
├── main.tf              # Main infrastructure configuration
├── variables.tf         # Variable definitions
├── outputs.tf           # Output values (public IP, DB endpoint)
├── terraform.tf         # Terraform and provider settings
├── ec2-key              # Private SSH key (DO NOT COMMIT TO GIT)
├── ec2-key.pub          # Public SSH key
├── Program.cs           # .NET Web API with IAM auth for PostgreSQL
├── webapi.csproj        # .NET project with Npgsql and AWS SDK
├── init-db.sql          # Database initialization script
└── README.md            # This file
```

## Infrastructure Components

### EC2 Instance
- **Type**: t2.micro
- **OS**: Amazon Linux 2023 (latest AMI)
- **Software**: .NET 9 SDK, PostgreSQL client
- **Ports**: 8080 (HTTP), 22 (SSH)
- **IAM Role**: Attached with RDS IAM authentication permissions

### RDS PostgreSQL Database
- **Engine**: PostgreSQL 16
- **Instance**: db.t3.micro
- **Database**: catalogdb
- **Table**: products (id SERIAL, name VARCHAR, created_at TIMESTAMP)
- **Storage**: 20 GB GP2
- **Authentication**: IAM database authentication enabled
- **Access**: From EC2 instance only (security group restricted)

### Security Features
- **IAM Authentication**: Database access uses temporary IAM tokens instead of static passwords
- **No Hardcoded Credentials**: Application retrieves auth tokens dynamically from AWS
- **SSL/TLS**: Database connections use SSL encryption
- **Least Privilege**: EC2 role has only `rds-db:connect` permission for specific database user

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `http_port` | HTTP port for the web server | 8080 | No |
| `db_username` | Database administrator username | dbadmin | No |
| `db_password` | Database admin password (only for initial setup) | - | **Yes** |

**Note**: The password is only used for initial database setup and creating the IAM-enabled user. After deployment, the application uses IAM authentication with temporary tokens.

```bash
export TF_VAR_db_password="YourSecurePassword123!"
```
| `http_port` | HTTP port for the web server | 8080 |
| `db_username` | Database administrator username | dbadmin |
| `db_password` | Database administrator password | (required) |

## Checking Application Logs

After SSH-ing into the instance, view the application logs:

```bash
# View the application log
sudo cat /var/log/webapi.log

# Follow the log in real-time
sudo tail -f /var/log/webapi.log

# Check if the application is running
ps aux | grep dotnet

# Check the port is listening
sudo netstat -tuln | grep 8080
# Or use ss
sudo ss -tlnp | grep 8080
```

### Troubleshooting: Log File Not Found

If `/var/log/webapi.log` doesn't exist, the application may not have started:

```bash
# Check if dotnet is running
ps aux | grep dotnet

# Check cloud-init logs to see if user_data script ran
sudo cat /var/log/cloud-init-output.log

# Try to start the application manually
cd /home/ec2-user/webapi
export DB_HOST=$(echo $DB_HOST)
export DB_NAME=$(echo $DB_NAME)
export DB_USER=$(echo $DB_USER)
export AWS_REGION=$(echo $AWS_REGION)

# If variables are not set, get them from Terraform
# DB_HOST should be the RDS endpoint from: terraform output db_endpoint

# Run the application in foreground to see errors
dotnet run

# Or run in background and create the log
nohup dotnet run > /var/log/webapi.log 2>&1 &
```

## Connecting to the Database

### From the Application
The .NET application automatically uses IAM authentication:
- Retrieves temporary auth tokens from AWS
- Tokens are valid for 15 minutes and refreshed automatically
- No credentials stored in code or environment variables

### Manual Connection with IAM Auth

To connect using IAM authentication from the EC2 instance:

```bash
# SSH into the instance
ssh -i ec2-key ec2-user@<PUBLIC_IP>

# Generate IAM auth token (valid for 15 minutes)
TOKEN=$(aws rds generate-db-auth-token \
  --hostname <DB_ENDPOINT> \
  --port 5432 \
  --region eu-central-1 \
  --username dbadmin)

# Connect using the token
psql "host=<DB_ENDPOINT> dbname=catalogdb user=dbadmin password=$TOKEN sslmode=require"

# Example queries
SELECT * FROM products;
INSERT INTO products (name) VALUES ('New Product');
```

### Initial Setup Connection (Password-based)

For initial database setup, the master password is used:

```bash
# Get the database endpoint from Terraform output
terraform output db_endpoint

# Connect with password (for admin tasks)
PGPASSWORD='your-password' psql -h <DB_ENDPOINT> -U dbadmin -d catalogdb
```

### Troubleshooting: .NET Not Installed

If you see `nohup: failed to run command 'dotnet': No such file or directory`, .NET wasn't installed. Manually install and run:

```bash
# Install .NET 9 SDK (Amazon Linux 2023)
sudo dnf install -y dotnet-sdk-9.0

# Verify installation
dotnet --version

# Navigate to the app directory
cd /home/ec2-user/webapi

# Build and run the application
dotnet build
nohup dotnet run > /var/log/webapi.log 2>&1 &

# Check if it's running
curl http://localhost:8080/
```

You can now access the API from your browser at `http://<PUBLIC_IP>:8080`

## Cleanup

To destroy all resources and avoid AWS charges:

```bash
terraform destroy
```

Type `yes` when prompted to confirm.

## Security Notes

⚠️ **Important Security Considerations:**

1. **IAM Authentication**: Database access uses IAM authentication with temporary tokens (15-minute validity), eliminating the need for long-lived database credentials in the application.
2. **SSH Key**: Never commit `ec2-key` (private key) to version control. Add it to `.gitignore`.
3. **Security Group**: The current configuration allows SSH and HTTP from any IP (`0.0.0.0/0`). For production, restrict to specific IP ranges.
4. **Database Password**: Only used for initial setup. The application never uses the master password.
5. **SSL/TLS**: All database connections use SSL encryption.
6. **IAM Roles**: EC2 instance uses IAM roles instead of access keys for AWS API calls.

## Region

This project is configured for the `eu-central-1` (Frankfurt) region. To change regions, modify the `region` parameter in [main.tf](main.tf).

## Support

For issues or questions:
1. Check Terraform logs: `terraform apply` with verbose output
2. Check AWS Console for resource status
3. SSH into the instance and check application logs

## License

This project is for demonstration purposes.
