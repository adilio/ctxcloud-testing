#!/bin/bash
# Deploy script for docker-container-host scenario

set -e

SCENARIO_NAME="docker-container-host"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../lib/checks.sh"

echo -e "🚀  Deploying scenario: $SCENARIO_NAME"
echo -e "🔍  Running pre-flight checks..."
run_all_checks

cd "$SCRIPT_DIR"

echo -e "📦  Initializing Terraform..."
terraform init -upgrade

echo -e "🔍  Validating configuration..."
terraform validate

echo -e "📐  Planning infrastructure..."
terraform plan -out=tfplan -var="lab_scenario=$SCENARIO_NAME"

echo -e "🚢  Applying infrastructure..."
terraform apply -auto-approve -var="owner=$OWNER" tfplan

PUBLIC_IP=$(terraform output -raw public_ip)
APP_URL=$(terraform output -raw app_url)

echo -e "\n✅  Deployment complete!"
echo -e "🔑  Public IP: $PUBLIC_IP"
echo -e "🌐  App URL: $APP_URL"
echo -e "⚠️   WARNING: Container running as root with risky mounts and IMDSv1 enabled."