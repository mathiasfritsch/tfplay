terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "tfplay-terraform-state-bucket"
    key            = "tfplay/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    # dynamodb_table = "terraform-state-lock"     # Optional: for state locking
  }
}
