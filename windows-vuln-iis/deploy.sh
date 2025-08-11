#!/usr/bin/env bash
# windows-vuln-iis — Deploy vulnerable Windows IIS server scenario

set -euo pipefail

# Load shared checks if available
if [ -f "../lib/checks.sh" ]; then
  # shellcheck disable=SC1091
  source "../lib/checks.sh"
  run_checks
fi

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

echo -e "${BLUE}🚀 Deploying Windows Vuln IIS Scenario...${NC}"

terraform init
terraform validate
terraform apply -auto-approve -var="owner=$OWNER"

echo -e "${GREEN}✅ Deploy complete!${NC}"
echo -e "----------------------------------------"
echo -e "${YELLOW}⚠️  CSPM/CDR Risks:${NC}"
echo -e "- Public RDP access"
echo -e "- IMDSv1 enabled"
echo -e "- Unencrypted root volume"
echo -e "- Canary secret and optional DSPM leak in webroot"
echo
echo -e "${BLUE}📝 Terraform Outputs:${NC}"
terraform output
echo
echo -e "${YELLOW}⚠️  SECURITY WARNING:${NC} This machine is intentionally misconfigured for lab purposes only. Do not expose to production networks."