# Get ECR repo URL from Terraform output
APP_ECR_URL=$(terraform -chdir=terraform output -raw app_tier_ecr_repository_url) # Run from project root

cd app-tier
docker build -t $APP_ECR_URL:latest .
docker push $APP_ECR_URL:latest
cd ..