output "web_load_balancer_dns" {
  description = "DNS name of the Web Tier Load Balancer"
  value       = aws_lb.web_alb.dns_name
}

output "app_load_balancer_dns" {
  description = "DNS name of the App Tier Load Balancer (REMOVED in Free Tier optimized version)"
  value       = "App Tier Load Balancer was not created in this Free Tier optimized configuration."
}

output "web_tier_ecr_repository_url" {
  description = "URL of the ECR repository for the web tier"
  value       = aws_ecr_repository.web_tier_repo.repository_url
}

output "app_tier_ecr_repository_url" {
  description = "URL of the ECR repository for the app tier"
  value       = aws_ecr_repository.app_tier_repo.repository_url
}

output "rds_instance_endpoint" {
  description = "Endpoint of the RDS instance (if created)"
  # Corrected to use an index [0] because aws_db_instance.default uses 'count'.
  # The try() function will handle the case where count = 0 and the resource is not created.
  value       = try(aws_db_instance.default[0].endpoint, "RDS not created or count is 0")
}

output "web_tier_user_data_example" {
  description = "Example user data for web tier with actual ECR repo URL"
  value = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user
              aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.${var.aws_region}.amazonaws.com
              docker pull ${aws_ecr_repository.web_tier_repo.repository_url}:latest
              docker run -d -p 3000:3000 ${aws_ecr_repository.web_tier_repo.repository_url}:latest
              EOF
  )
}

output "app_tier_user_data_example" {
  description = "Example user data for app tier with actual ECR repo URL (WARNING: Will likely fail without NAT Gateway or VPC Endpoints for internet/ECR)"
  value = base64encode(<<-EOF
              #!/bin/bash
              # WARNING: yum update and docker pull WILL FAIL without NAT Gateway or VPC Endpoints for internet/ECR access.
              yum update -y
              amazon-linux-extras install docker -y
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user
              aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.${var.aws_region}.amazonaws.com
              docker pull ${aws_ecr_repository.app_tier_repo.repository_url}:latest
              docker run -d -p 5000:5000 ${aws_ecr_repository.app_tier_repo.repository_url}:latest
              EOF
  )
}