# Three-Tier Google Drive Clone on AWS

A personal Google Drive clone built on AWS using a three-tier architecture with Terraform infrastructure as code.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                            VPC (10.0.0.0/16)                            ││
│  │                                                                          ││
│  │  ┌──────────────────────────────────────────────────────────────────┐   ││
│  │  │              TIER 3 - PRESENTATION (User Tier)                    │   ││
│  │  │    Public Subnets (10.0.1.0/24, 10.0.2.0/24)                     │   ││
│  │  │  ┌─────────────┐    ┌─────────────────────────────────┐          │   ││
│  │  │  │ Application │───▶│   EC2 Auto Scaling Group        │          │   ││
│  │  │  │ Load        │    │   (Node.js Web UI)              │          │   ││
│  │  │  │ Balancer    │    │   Port: 3000                    │          │   ││
│  │  │  └─────────────┘    └─────────────────────────────────┘          │   ││
│  │  └──────────────────────────────────────────────────────────────────┘   ││
│  │                                    │                                     ││
│  │                                    ▼                                     ││
│  │  ┌──────────────────────────────────────────────────────────────────┐   ││
│  │  │              TIER 2 - APPLICATION (App Tier)                      │   ││
│  │  │    Private Subnets (10.0.3.0/24, 10.0.4.0/24)                    │   ││
│  │  │  ┌─────────────────────────────────┐                             │   ││
│  │  │  │   EC2 Auto Scaling Group        │──────┐                      │   ││
│  │  │  │   (Python Flask API)            │      │                      │   ││
│  │  │  │   Port: 5000                    │      │                      │   ││
│  │  │  └─────────────────────────────────┘      │                      │   ││
│  │  └───────────────────────────────────────────│──────────────────────┘   ││
│  │                                    │         │                           ││
│  │                                    ▼         ▼                           ││
│  │  ┌──────────────────────────────────────────────────────────────────┐   ││
│  │  │              TIER 1 - DATABASE (DB Tier)                          │   ││
│  │  │    Private Subnets (10.0.5.0/24, 10.0.6.0/24)                    │   ││
│  │  │  ┌─────────────────────────────────┐                             │   ││
│  │  │  │   PostgreSQL RDS               │                              │   ││
│  │  │  │   (File Metadata)              │                              │   ││
│  │  │  │   Port: 5432                   │                              │   ││
│  │  │  └─────────────────────────────────┘                             │   ││
│  │  └──────────────────────────────────────────────────────────────────┘   ││
│  │                                                                          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │                        STORAGE SERVICE                                    ││
│  │  ┌─────────────────────────────────┐                                     ││
│  │  │   S3 Bucket                     │                                     ││
│  │  │   (File Storage)                │                                     ││
│  │  │   - Versioning enabled          │                                     ││
│  │  │   - Server-side encryption      │                                     ││
│  │  │   - Lifecycle policies          │                                     ││
│  │  └─────────────────────────────────┘                                     ││
│  └──────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

### Tier 1 - Database Tier (T1)
- **Service**: Amazon RDS PostgreSQL
- **Purpose**: Stores file metadata (names, paths, user info, permissions)
- **Location**: Private subnets for security
- **Port**: 5432

### Tier 2 - Application Tier (T2)
- **Service**: EC2 Auto Scaling Group running Python Flask
- **Purpose**: API layer for file operations
- **Location**: Private subnets
- **Port**: 5000
- **Features**:
  - File upload to S3
  - File download from S3
  - File deletion
  - File listing
  - Presigned URL generation
  - Storage statistics

### Tier 3 - Presentation Tier (T3)
- **Service**: EC2 Auto Scaling Group running Node.js Express
- **Purpose**: Web UI for user interaction
- **Location**: Public subnets (behind ALB)
- **Port**: 3000
- **Features**:
  - Google Drive-like UI
  - Drag and drop file upload
  - File browser
  - Search functionality
  - Storage usage display

### Storage Service
- **Service**: Amazon S3
- **Purpose**: Actual file content storage
- **Features**:
  - Versioning enabled (file recovery)
  - Server-side encryption (AES-256)
  - Lifecycle policies (cost optimization)
  - CORS configuration (web uploads)
  - Public access blocked

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed
3. **Docker** installed (for building images)
4. **AWS CLI** configured with credentials

## Deployment

### Step 1: Initialize Terraform

```bash
cd terraform
terraform init
```

### Step 2: Review the Plan

```bash
terraform plan
```

### Step 3: Deploy Infrastructure

```bash
terraform apply
```

### Step 4: Build and Push Docker Images

```bash
# Get ECR repository URLs
export WEB_ECR_URL=$(terraform output -raw web_tier_ecr_repository_url)
export APP_ECR_URL=$(terraform output -raw app_tier_ecr_repository_url)

# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $WEB_ECR_URL
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $APP_ECR_URL

# Build and push web tier
cd ../web-tier
docker build -t $WEB_ECR_URL:latest .
docker push $WEB_ECR_URL:latest

# Build and push app tier
cd ../app-tier
docker build -t $APP_ECR_URL:latest .
docker push $APP_ECR_URL:latest
```

### Step 5: Access the Application

```bash
# Get the load balancer DNS
terraform output web_load_balancer_dns
```

Open the DNS URL in your browser to access the Google Drive clone UI.

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | us-east-1 |
| `project_name` | Project prefix | three-tier |
| `environment` | Environment name | dev |
| `vpc_cidr` | VPC CIDR block | 10.0.0.0/16 |
| `db_name` | Database name | drivedb |
| `db_username` | Database username | admin |
| `db_password` | Database password | Admin@3Tear |
| `enable_rds` | Enable RDS creation | false |

## API Endpoints

### App Tier API (Port 5000)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API information |
| GET | `/health` | Health check |
| GET | `/files` | List all files |
| POST | `/files/upload` | Upload a file |
| GET | `/files/download/{file_id}` | Download a file |
| DELETE | `/files/{file_id}` | Delete a file |
| GET | `/files/{file_id}/info` | Get file metadata |
| GET | `/files/{file_id}/presigned` | Get presigned URL |
| GET | `/storage/stats` | Get storage statistics |

## Security Features

1. **Network Security**:
   - VPC isolation
   - Security groups with least-privilege access
   - Private subnets for database and application tiers

2. **Data Security**:
   - S3 bucket encryption (AES-256)
   - S3 public access blocked
   - RDS in private subnets

3. **IAM**:
   - Least-privilege IAM roles
   - Instance profiles for EC2

## Cost Optimization

- **Free Tier Optimized**: NAT Gateway removed by default
- **S3 Lifecycle Policies**: Automatic transition to cheaper storage classes
- **RDS Disabled by Default**: Enable when needed
- **t2.micro instances**: Free tier eligible

## Enabling RDS Database

To enable the PostgreSQL database for storing file metadata:

1. Update `terraform/variables.tf` or create `terraform.tfvars`:
   ```hcl
   enable_rds = true
   db_password = "YourSecurePassword"
   ```

2. Re-apply Terraform:
   ```bash
   terraform apply
   ```

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

**Note**: S3 buckets with objects must be emptied before destruction. Use:
```bash
aws s3 rm s3://your-bucket-name --recursive
```

## Future Enhancements

- [ ] User authentication (Cognito)
- [ ] File sharing with presigned URLs
- [ ] Folder support
- [ ] File versioning UI
- [ ] Search by file content
- [ ] Thumbnail generation for images
- [ ] Real-time sync

## License

MIT
