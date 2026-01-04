output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.example.public_ip
}

output "db_endpoint" {
  description = "PostgreSQL database endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
}
