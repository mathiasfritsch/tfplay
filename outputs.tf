output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web_server.name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.web_server.dns_name
}

output "ssh_connection_info" {
  description = "SSH connection instructions"
  value       = "Use 'ssh -i ec2-key ec2-user@<instance-ip>' to connect to instances"
}
