#!/usr/bin/env bash
# lib/checks.sh — Common preflight checks for ctxcloud-testing

set -euo pipefail

print_banner() {
    tput setaf 6
    echo "==== $1 ===="
    tput sgr0
}

error_exit() {
    tput setaf 1
    echo "❌ $1"
    tput sgr0
    exit 1
}

green() { tput setaf 2; }
yellow() { tput setaf 3; }
red() { tput setaf 1; }
blue() { tput setaf 4; }
cyan() { tput setaf 6; }
resetc() { tput sgr0; }

status() { green; echo "✅ $1"; resetc; }
warn() { yellow; echo "⚠️  $1"; resetc; }
error() { red; echo "❌ $1"; resetc; exit 1; }
info() { cyan; echo "ℹ️  $1"; resetc; }

# Terraform check
check_terraform() {
    if ! command -v terraform >/dev/null 2>&1; then
        error_exit "Terraform is not installed. Please install: https://developer.hashicorp.com/terraform/downloads"
    fi
}

# AWS CLI check
check_awscli() {
    if ! command -v aws >/dev/null 2>&1; then
        error_exit "AWS CLI is not installed. Install: https://aws.amazon.com/cli/"
    fi
}

# AWS credentials check
check_awsauth() {
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        error_exit "AWS CLI is not authenticated. Run: aws configure"
    fi
}

# Region validation
check_region() {
    local region="$1"
    if ! aws ec2 describe-regions --query "Regions[].RegionName" --output text | grep -qw "$region"; then
        error_exit "Region '$region' is not valid. Please select a valid AWS region."
    fi
}

run_checks() {
    if [[ "${1:-}" == "--skip-checks" ]] || [[ "${SKIP_CHECKS:-false}" == "true" ]]; then
        warn "Skipping preflight checks."
        return
    fi
    print_banner "Running preflight checks..."
    check_terraform
    check_awscli
    check_awsauth
    check_region "${TF_VAR_region:-us-east-1}"
    status "All checks passed."
}
