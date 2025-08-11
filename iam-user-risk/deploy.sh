#!/usr/bin/env bash
# iam-user-risk — Deploy IAM misconfiguration scenario

set -euo pipefail

# Load shared checks and styling
if [ -f "../lib/checks.sh" ]; then
  # shellcheck disable=SC1091
  source "../lib/checks.sh"
  run_checks
fi

# Colors for status messages
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

echo -e "${BLUE}🚀 Deploying IAM User Risk Scenario...${NC}"

terraform init
terraform validate
terraform apply -auto-approve -var="owner=$OWNER"

echo -e "${GREEN}✅ Deploy complete!${NC}"
echo -e "----------------------------------------"
echo -e "${YELLOW}🔐 CIEM Risk Details:${NC}"
echo -e "- IAM user without MFA"
echo -e "- Two simultaneous active access keys"
echo -e "- Broad administrator-level inline policy"
echo -e "- Optional weak account password policy enabled"
echo
echo -e "${BLUE}📝 Terraform Outputs:${NC}"
terraform output
echo
echo -e "${YELLOW}⚠️  SECURITY WARNING:${NC} This identity has excessive privileges and poor security hygiene. Use only in an isolated lab."