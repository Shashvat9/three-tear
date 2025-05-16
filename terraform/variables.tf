variable "aws_region" {
  description = "AWS region for the resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A name for the project to prefix resources"
  type        = string
  default     = "three-tier"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_az1_cidr" {
  description = "CIDR block for public subnet in AZ1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_az2_cidr" {
  description = "CIDR block for public subnet in AZ2"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_az1_cidr" {
  description = "CIDR block for private subnet in AZ1 for App Tier"
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_az2_cidr" {
  description = "CIDR block for private subnet in AZ2 for App Tier"
  type        = string
  default     = "10.0.4.0/24"
}

variable "db_subnet_az1_cidr" {
  description = "CIDR block for private DB subnet in AZ1"
  type        = string
  default     = "10.0.5.0/24"
}

variable "db_subnet_az2_cidr" {
  description = "CIDR block for private DB subnet in AZ2"
  type        = string
  default     = "10.0.6.0/24"
}

variable "db_username" {
  description = "Username for the RDS database"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  default     = "Admin@3Tear" # CHANGE THIS!
  sensitive   = true
}