#!/usr/bin/env bash
# iam-user-risk — Teardown IAM misconfiguration scenario

set -euo pipefail

if [ -f "../lib/checks.sh" ]; then
  # shellcheck disable=SC1091
  source "../lib/checks.sh"
fi

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

echo -e "${BLUE}🗑️  Tearing down IAM User Risk Scenario...${NC}"

# Remove IAM access keys first to avoid dependency errors
USER_NAME=$(terraform output -raw iam_user_name 2>/dev/null || echo "")

if [ -n "$USER_NAME" ]; then
  for KEY_ID in $(aws iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null); do
    echo -e "${YELLOW}🔑 Deleting access key: ${KEY_ID}${NC}"
    aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$KEY_ID" || true
  done
else
  echo -e "${YELLOW}⚠️  No IAM username from terraform output, proceeding to destroy.${NC}"
fi

if terraform destroy -auto-approve; then
  # Clean up Terraform state and lock files
  rm -f "$(dirname "$0")/terraform.tfstate" "$(dirname "$0")/terraform.tfstate.backup" "$(dirname "$0")/.terraform.lock.hcl"
  rm -rf "$(dirname "$0")/.terraform"
  echo -e "${GREEN}✅ Teardown complete!${NC}"
else
  echo -e "${RED}❌ Teardown failed, Terraform files preserved for troubleshooting.${NC}"
  exit 1
fi