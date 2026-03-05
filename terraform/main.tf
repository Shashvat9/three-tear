terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Availability Zones ---
data "aws_availability_zones" "available" {}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# --- Subnets ---
resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_az1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-public-subnet-az1"
  }
}

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_az2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-public-subnet-az2"
  }
}

resource "aws_subnet" "private_app_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_az1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "${var.project_name}-private-app-subnet-az1"
  }
}

resource "aws_subnet" "private_app_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_az2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "${var.project_name}-private-app-subnet-az2"
  }
}

resource "aws_subnet" "private_db_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_az1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "${var.project_name}-private-db-subnet-az1"
  }
}

resource "aws_subnet" "private_db_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_az2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "${var.project_name}-private-db-subnet-az2"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# --- Elastic IP for NAT Gateway (REMOVED FOR FREE TIER OPTIMIZATION) ---
# resource "aws_eip" "nat_eip_az1" {
#   domain   = "vpc"
#   tags = {
#     Name = "${var.project_name}-nat-eip-az1"
#   }
# }

# --- NAT Gateway (REMOVED FOR FREE TIER OPTIMIZATION) ---
# WARNING: Removing NAT Gateway means instances in private subnets will NOT have outbound internet access.
# This will break user_data scripts that need to download packages or pull images from public ECR.
# resource "aws_nat_gateway" "nat_gw_az1" {
#   allocation_id = aws_eip.nat_eip_az1.id
#   subnet_id     = aws_subnet.public_az1.id
#   tags = {
#     Name = "${var.project_name}-nat-gw-az1"
#   }
#   depends_on = [aws_internet_gateway.gw]
# }

# --- Route Tables ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id
  # Route to NAT Gateway REMOVED. Instances in these subnets will not have internet access.
  # route {
  #   cidr_block     = "0.0.0.0/0"
  #   nat_gateway_id = aws_nat_gateway.nat_gw_az1.id
  # }
  tags = {
    Name = "${var.project_name}-private-app-rt"
  }
}

resource "aws_route_table_association" "private_app_az1" {
  subnet_id      = aws_subnet.private_app_az1.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table_association" "private_app_az2" {
  subnet_id      = aws_subnet.private_app_az2.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-private-db-rt"
  }
}

resource "aws_route_table_association" "private_db_az1" {
  subnet_id      = aws_subnet.private_db_az1.id
  route_table_id = aws_route_table.private_db.id
}
resource "aws_route_table_association" "private_db_az2" {
  subnet_id      = aws_subnet.private_db_az2.id
  route_table_id = aws_route_table.private_db.id
}


# --- Security Groups ---
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Allow HTTP/HTTPS inbound traffic for Web Tier EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80 # Actually traffic will come from ALB to this port if ALB target is port 80/3000
    to_port     = 80 # Port the instance listens on if mapped from container 3000 to host 80. For ALB, this rule should allow from web_lb_sg on port 3000
    protocol    = "tcp"
    security_groups = [aws_security_group.web_lb_sg.id] # Allow from Web LB
  }
  # If your EC2 instances listen on 3000 (Node app port) and ALB forwards to 3000:
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.web_lb_sg.id] # Allow from Web LB to actual app port
  }

   # Allow SSH for troubleshooting (restrict to your IP if possible)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # CHANGE THIS TO YOUR IP: e.g. "YOUR_IP/32"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allows all outbound communication
  }
  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Allow traffic from Web Tier SG to App Tier EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5000 # Port App tier listens on
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Allow from Web Tier EC2 instances' SG
  }
   # Allow SSH for troubleshooting (restrict to your IP if possible)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # CHANGE THIS TO YOUR IP
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Allow traffic from App Tier SG to RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432 # PostgreSQL. For MySQL: 3306
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id] # Allow from App Tier SG
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

resource "aws_security_group" "web_lb_sg" {
  name        = "${var.project_name}-web-lb-sg"
  description = "Allow HTTP/HTTPS for Web Load Balancer"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Public internet
  }
  ingress {
    from_port   = 443 # If using HTTPS
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress { # ALB needs to talk to instances in web_sg
    from_port   = 0 # Or restrict to specific ports like 3000 if you know them
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Can be restricted to VPC CIDR or specific subnets
  }
  tags = { Name = "${var.project_name}-web-lb-sg" }
}

# App Tier Load Balancer Security Group REMOVED
# resource "aws_security_group" "app_lb_sg" { ... }


# --- ECR Repositories ---
resource "aws_ecr_repository" "web_tier_repo" {
  name                 = "${var.project_name}-web-tier"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "${var.project_name}-web-tier-ecr" }
}

resource "aws_ecr_repository" "app_tier_repo" {
  name                 = "${var.project_name}-app-tier"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "${var.project_name}-app-tier-ecr" }
}

# --- S3 Storage Bucket (Google Drive Clone Storage Service) ---
resource "aws_s3_bucket" "storage_bucket" {
  bucket = "${var.project_name}-storage-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-storage-bucket"
    Purpose     = "Google Drive Clone File Storage"
    Environment = var.environment
  }
}

# Random suffix to ensure bucket name uniqueness
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Enable versioning for the storage bucket (important for file recovery)
resource "aws_s3_bucket_versioning" "storage_versioning" {
  bucket = aws_s3_bucket.storage_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for security
resource "aws_s3_bucket_server_side_encryption_configuration" "storage_encryption" {
  bucket = aws_s3_bucket.storage_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to the storage bucket
resource "aws_s3_bucket_public_access_block" "storage_public_access" {
  bucket = aws_s3_bucket.storage_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for cost optimization (move old versions to cheaper storage)
resource "aws_s3_bucket_lifecycle_configuration" "storage_lifecycle" {
  bucket = aws_s3_bucket.storage_bucket.id

  rule {
    id     = "move-old-versions-to-glacier"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# CORS configuration for web uploads
resource "aws_s3_bucket_cors_configuration" "storage_cors" {
  bucket = aws_s3_bucket.storage_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"] # In production, restrict to your domain
    expose_headers  = ["ETag", "Content-Length", "Content-Type"]
    max_age_seconds = 3000
  }
}

# --- IAM Role for EC2 Instances ---
resource "aws_iam_role" "ec2_instance_role" {
  name = "${var.project_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = { Name = "${var.project_name}-ec2-role" }
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_readonly" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3 access policy for App Tier to interact with the storage bucket
resource "aws_iam_policy" "s3_storage_policy" {
  name        = "${var.project_name}-s3-storage-policy"
  description = "Policy for App Tier to access S3 storage bucket for Google Drive clone"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion"
        ]
        Resource = [
          aws_s3_bucket.storage_bucket.arn,
          "${aws_s3_bucket.storage_bucket.arn}/*"
        ]
      }
    ]
  })
  tags = { Name = "${var.project_name}-s3-storage-policy" }
}

resource "aws_iam_role_policy_attachment" "ec2_s3_storage" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.s3_storage_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_instance_role.name
  tags = { Name = "${var.project_name}-ec2-profile" }
}


# --- Web Tier: Application Load Balancer, Target Group, Launch Template, Auto Scaling Group ---
resource "aws_lb" "web_alb" {
  name               = "${var.project_name}-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_lb_sg.id]
  subnets            = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
  tags               = { Name = "${var.project_name}-web-alb" }
}

resource "aws_lb_target_group" "web_tg" {
  name        = "${var.project_name}-web-tg"
  port        = 3000 # Port web app runs on inside container and EC2 instance listens
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    port                = "3000" # Health check on app port
  }
  tags = { Name = "${var.project_name}-web-tg" }
}

resource "aws_lb_listener" "web_http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "web_lt" {
  name_prefix   = "${var.project_name}-web-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  iam_instance_profile { arn = aws_iam_instance_profile.ec2_profile.arn }
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user
              aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.${var.aws_region}.amazonaws.com
              docker pull ${aws_ecr_repository.web_tier_repo.repository_url}:latest
              # Run web tier with app tier URL for API calls
              docker run -d -p 3000:3000 \
                -e APP_TIER_URL=http://${aws_lb.web_alb.dns_name}:5000 \
                ${aws_ecr_repository.web_tier_repo.repository_url}:latest
              EOF
  )
  # key_name = "your-key-pair-name"
  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-web-instance" }
  }
  depends_on = [aws_iam_instance_profile.ec2_profile, aws_ecr_repository.web_tier_repo]
}

resource "aws_autoscaling_group" "web_asg" {
  name                = "${var.project_name}-web-asg"
  desired_capacity    = 1
  max_size            = 1 # Reduced max_size for cost saving, can be 2 for minimal HA
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }
  target_group_arns         = [aws_lb_target_group.web_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  tag {
    key                 = "Name"
    value               = "${var.project_name}-web-asg-instance"
    propagate_at_launch = true
  }
  depends_on = [aws_lb_target_group.web_tg]
}


# --- App Tier: Load Balancer and related resources REMOVED ---
# resource "aws_lb" "app_alb" { ... }
# resource "aws_lb_target_group" "app_tg" { ... }
# resource "aws_lb_listener" "app_http" { ... }

resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.project_name}-app-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  iam_instance_profile { arn = aws_iam_instance_profile.ec2_profile.arn }
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  user_data = base64encode(<<-EOF
              #!/bin/bash
              # WARNING: yum update and docker pull WILL FAIL without NAT Gateway or VPC Endpoints for internet/ECR access.
              # Consider pre-baking AMI or using VPC Endpoints if NAT Gateway is removed.
              yum update -y
              amazon-linux-extras install docker -y
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user
              # The following line will fail without internet access from private subnet
              aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.${var.aws_region}.amazonaws.com
              # The following line will fail if the above ECR login fails or image cannot be pulled
              docker pull ${aws_ecr_repository.app_tier_repo.repository_url}:latest
              # Run the app tier with S3 bucket and DB configuration
              docker run -d -p 5000:5000 \
                -e S3_BUCKET_NAME=${aws_s3_bucket.storage_bucket.bucket} \
                -e AWS_REGION=${var.aws_region} \
                -e DB_HOST=${try(aws_db_instance.default[0].address, "localhost")} \
                -e DB_NAME=${var.db_name} \
                -e DB_USERNAME=${var.db_username} \
                -e DB_PASSWORD=${var.db_password} \
                ${aws_ecr_repository.app_tier_repo.repository_url}:latest
              EOF
  )
  # key_name = "your-key-pair-name"
  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-app-instance" }
  }
  depends_on = [aws_iam_instance_profile.ec2_profile, aws_ecr_repository.app_tier_repo, aws_s3_bucket.storage_bucket]
}

resource "aws_autoscaling_group" "app_asg" {
  name                = "${var.project_name}-app-asg"
  desired_capacity    = 1
  max_size            = 1 # Reduced max_size for cost saving
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.private_app_az1.id, aws_subnet.private_app_az2.id]
  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
  # target_group_arns removed as App ALB is removed
  health_check_type         = "EC2" # Changed to EC2 as no ELB for health checks
  health_check_grace_period = 300
  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-asg-instance"
    propagate_at_launch = true
  }
  # depends_on = [aws_lb_target_group.app_tg] # Dependency removed
}


# --- Data Tier: RDS (Optional) ---
resource "aws_db_subnet_group" "default" {
  # count      = var.enable_rds ? 1 : 0 # Control RDS creation with a variable
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_db_az1.id, aws_subnet.private_db_az2.id]
  tags       = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "default" {
  count = 0 # Keep RDS commented out by default to save costs unless explicitly needed
            # To enable, change count to 1 and ensure var.db_password is set.
            # Also, ensure you have a valid engine_version for your region.

  identifier             = "${var.project_name}-rds-instance"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "14.11" # EXAMPLE - VERIFY AND UPDATE for your region!
  instance_class         = "db.t3.micro"
  username               = var.db_username
  password               = var.db_password # Ensure this is set if count = 1
  parameter_group_name   = "default.postgres14"
  db_subnet_group_name   = aws_db_subnet_group.default.name # Use aws_db_subnet_group.default[0].name if count is used here
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  tags                   = { Name = "${var.project_name}-rds-instance" }
  # depends_on             = [aws_db_subnet_group.default] # Use aws_db_subnet_group.default[0] if count is used
}

# SSM Parameter Store remains a good practice, but actual creation can be conditional
# based on whether RDS is created, or used for other parameters.