#!/bin/bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Colors / Icons
green() { tput setaf 2; }
yellow() { tput setaf 3; }
red() { tput setaf 1; }
cyan() { tput setaf 6; }
resetc() { tput sgr0; }
status() { green; echo "✅ $1"; resetc; }
warn() { yellow; echo "⚠️  $1"; resetc; }
error() { red; echo "❌ $1"; resetc; exit 1; }
info() { cyan; echo "ℹ️  $1"; resetc; }

info "🗑️  Starting teardown for linux-misconfig-web..."
if terraform -chdir="$SCRIPT_DIR" destroy -auto-approve; then
  status "Teardown complete for linux-misconfig-web."
  # Clean up Terraform state and lock files
  rm -f "$SCRIPT_DIR/terraform.tfstate" "$SCRIPT_DIR/terraform.tfstate.backup" "$SCRIPT_DIR/.terraform.lock.hcl"
  rm -rf "$SCRIPT_DIR/.terraform"
else
  error "Teardown failed, Terraform files preserved for troubleshooting."
fi
