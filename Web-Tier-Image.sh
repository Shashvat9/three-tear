# Get ECR repo URL from Terraform output
WEB_ECR_URL=$(terraform -chdir=terraform output -raw web_tier_ecr_repository_url) # Run from project root

cd web-tier
docker build -t $WEB_ECR_URL:latest .
docker push $WEB_ECR_URL:latest
cd ..