#!/bin/bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/checks.sh"

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

# Auto-generate dummy_api_key if unset or default
DEFAULT_KEY="sk_live_51H6kP7kYbQe9Lm3e8xT7wzAq5b6Vn"
if [[ -z "${TF_VAR_dummy_api_key:-}" || "${TF_VAR_dummy_api_key}" == "$DEFAULT_KEY" ]]; then
  GEN_KEY="ghp_$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)"
  export TF_VAR_dummy_api_key="$GEN_KEY"
  warn "Generated random dummy API key for this deployment."
fi

info "🚀 Starting deployment for linux-misconfig-web..."
terraform -chdir="$SCRIPT_DIR" init
terraform -chdir="$SCRIPT_DIR" validate
terraform -chdir="$SCRIPT_DIR" apply -auto-approve

# Output summary
PUB_IP=$(terraform -chdir="$SCRIPT_DIR" output -raw public_ip 2>/dev/null || echo "N/A")
PUB_DNS=$(terraform -chdir="$SCRIPT_DIR" output -raw public_dns 2>/dev/null || echo "N/A")
status "Deployment complete!"
echo
info "🌐 Public IP: $(yellow)$PUB_IP$(resetc)"
info "🔗 Access: http://$PUB_IP"
info "🖥️  Public DNS: $PUB_DNS"
echo
warn "To teardown this environment, run:"
echo "    cd \"$SCRIPT_DIR\" && ./teardown.sh"
