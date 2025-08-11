#!/usr/bin/env bash
# windows-vuln-iis — Teardown vulnerable Windows IIS server scenario

set -euo pipefail

if [ -f "../lib/checks.sh" ]; then
  # shellcheck disable=SC1091
  source "../lib/checks.sh"
fi

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

echo -e "${BLUE}🗑️  Tearing down Windows Vuln IIS Scenario...${NC}"

if terraform destroy -auto-approve; then
  # Clean up Terraform state and lock files
  rm -f "$(dirname "$0")/terraform.tfstate" "$(dirname "$0")/terraform.tfstate.backup" "$(dirname "$0")/.terraform.lock.hcl"
  rm -rf "$(dirname "$0")/.terraform"
  echo -e "${GREEN}✅ Teardown complete!${NC}"
else
  echo -e "${RED}❌ Teardown failed, Terraform files preserved for troubleshooting.${NC}"
  exit 1
fi