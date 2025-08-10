#!/bin/bash
# Teardown script for docker-container-host scenario

set -e

SCENARIO_NAME="docker-container-host"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "🧹  Tearing down scenario: $SCENARIO_NAME"

cd "$SCRIPT_DIR"

echo -e "🔻  Destroying infrastructure..."
terraform destroy -auto-approve -var="lab_scenario=$SCENARIO_NAME"

echo -e "✅  Teardown complete for: $SCENARIO_NAME"