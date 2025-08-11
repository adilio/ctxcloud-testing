#!/bin/bash
# Teardown script for docker-container-host scenario

set -e

SCENARIO_NAME="docker-container-host"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "🧹  Tearing down scenario: $SCENARIO_NAME"

cd "$SCRIPT_DIR"

echo -e "🔻  Destroying infrastructure..."
if terraform destroy -auto-approve -var="lab_scenario=$SCENARIO_NAME"; then
  # Clean up Terraform state and lock files
  rm -f "$SCRIPT_DIR/terraform.tfstate" "$SCRIPT_DIR/terraform.tfstate.backup" "$SCRIPT_DIR/.terraform.lock.hcl"
  rm -rf "$SCRIPT_DIR/.terraform"
  echo -e "✅  Teardown complete for: $SCENARIO_NAME"
else
  echo -e "❌  Teardown failed, Terraform files preserved for troubleshooting."
  exit 1
fi