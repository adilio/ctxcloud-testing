#!/usr/bin/env bash
# menu.sh — ctxcloud-testing TUI
set -euo pipefail

# ---------- Defaults ----------
export TF_VAR_region="${TF_VAR_region:-us-east-1}"
export TF_VAR_owner="${TF_VAR_owner:-aleghari}"

# Ensure they are exported for subshells and preserved in TUI
[ -z "${TF_VAR_region}" ] && export TF_VAR_region="us-east-1"
[ -z "${TF_VAR_owner}" ] && export TF_VAR_owner="aleghari"
export TF_VAR_allow_ssh_cidr="${TF_VAR_allow_ssh_cidr:-}"   # TUI may set this
LOG_DIR="${LOG_DIR:-logs}"
SESSION_SSH_CIDR="${SESSION_SSH_CIDR:-}"                    # cached after first prompt

mkdir -p "$LOG_DIR"

# ---------- Colors and Style ----------
c() { tput setaf "$1" 2>/dev/null || true; }
r() { tput sgr0 2>/dev/null || true; }
bold() { tput bold 2>/dev/null || true; }
ul() { tput smul 2>/dev/null || true; }
green() { c 2; }
yellow() { c 3; }
red() { c 1; }
blue() { c 4; }
magenta() { c 5; }
cyan() { c 6; }

banner() {
  echo
  cyan; bold; echo "====== $1 ======"; r;
  echo
}

status() { green; echo "✅ $1"; r; }
warn() { yellow; echo "⚠️  $1"; r; }
error() {
  red; echo "❌ $1"; r;
  echo
  info "💡 Troubleshooting Tips:"
  case "$1" in
    *"Terraform not installed"*)
      info "  • Download from: https://developer.hashicorp.com/terraform/downloads"
      info "  • On macOS: brew install terraform"
      info "  • Verify installation: terraform --version"
      ;;
    *"AWS CLI not installed"*)
      info "  • Download from: https://aws.amazon.com/cli/"
      info "  • On macOS: brew install awscli"
      info "  • Verify installation: aws --version"
      ;;
    *"AWS credentials invalid"*)
      info "  • Run: aws configure"
      info "  • Ensure you have programmatic access keys"
      info "  • Test with: aws sts get-caller-identity"
      info "  • Check region availability: aws ec2 describe-regions"
      ;;
    *"No executable teardown.sh"*)
      info "  • Check if the file exists: ls -la $2/teardown.sh"
      info "  • Make executable: chmod +x $2/teardown.sh"
      info "  • Or use the .sh permissions prompt at startup"
      ;;
    *)
      info "  • Check the logs directory for detailed error information"
      info "  • Ensure you're running in the correct directory"
      info "  • Verify AWS permissions for EC2, IAM, and S3 operations"
      ;;
  esac
  echo
  exit 1
}
info() { blue; echo "ℹ️  $1"; r; }

# ---------- Preflight checks ----------
run_checks() {
  # Prompt to ensure all .sh scripts are executable
  read -r -p "Ensure all .sh scripts in repo are executable? [Y/n]: " ensure_exec
  ensure_exec="${ensure_exec:-Y}"
  if [[ "${ensure_exec,,}" =~ ^(y|yes)$ ]]; then
    find . -type f -name "*.sh" -exec chmod +x {} \;
    status "All .sh scripts have been made executable."
  else
    warn "Skipping chmod for .sh scripts."
  fi

  if [ -f "./lib/checks.sh" ]; then
    # shellcheck disable=SC1091
    source "./lib/checks.sh"
    if command -v run_checks >/dev/null 2>&1; then
      run_checks
      return
    fi
  fi
  info "Running preflight checks..."
  command -v terraform >/dev/null || error "Terraform not installed. Get it: https://developer.hashicorp.com/terraform/downloads"
  command -v aws >/dev/null || error "AWS CLI not installed. Get it: https://aws.amazon.com/cli/"
  aws sts get-caller-identity >/dev/null 2>&1 || error "AWS credentials invalid or missing. Run 'aws configure'."
  status "All checks passed."
}

# ---------- Public IP detection ----------
is_ipv4() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r a b c d <<<"$ip"
  for o in "$a" "$b" "$c" "$d"; do
    [ "$o" -ge 0 ] && [ "$o" -le 255 ] || return 1
  done
  return 0
}

detect_public_ip() {
  local cand=""
  for cmd in \
    "curl -fsS --max-time 2 https://checkip.amazonaws.com" \
    "curl -fsS --max-time 2 https://api.ipify.org" \
    "curl -fsS --max-time 2 https://ipv4.icanhazip.com" \
    "dig +short myip.opendns.com @resolver1.opendns.com"
  do
    cand="$(bash -c "$cmd" 2>/dev/null | tr -d '\r' | head -n1 || true)"
    if is_ipv4 "$cand"; then
      echo "$cand"
      return 0
    fi
  done
  return 1
}

prompt_for_ssh_cidr() {
  # Skip if already set this session or env provided
  if [ -n "${TF_VAR_allow_ssh_cidr}" ]; then
    SESSION_SSH_CIDR="$TF_VAR_allow_ssh_cidr"
    return
  fi
  if [ -n "${SESSION_SSH_CIDR}" ]; then
    export TF_VAR_allow_ssh_cidr="$SESSION_SSH_CIDR"
    return
  fi

  banner "SSH Access Setup"
  local detected="" choice="" custom=""
  if detected="$(detect_public_ip)"; then
    info "Detected public IP: $detected"
    echo "Use $detected/32 for SSH? [Y]es/[N]o/[C]ustom/[S]kip"
    read -r -p "Choice: " choice
  else
    warn "Could not detect your public IP automatically."
    read -r -p "Enter custom CIDR (e.g., 198.51.100.42/32), or press Enter to skip: " custom
    choice="c"
  fi

  case "${choice,,}" in
    ""|"y"|"yes")
      [ -n "$detected" ] && SESSION_SSH_CIDR="${detected}/32" || SESSION_SSH_CIDR=""
      ;;
    "c"|"custom")
      if [ -z "$custom" ]; then
        read -r -p "Custom CIDR: " custom
      fi
      SESSION_SSH_CIDR="$custom"
      ;;
    "s"|"skip"|"n"|"no")
      SESSION_SSH_CIDR=""
      ;;
    *)
      [ -n "$detected" ] && SESSION_SSH_CIDR="${detected}/32" || SESSION_SSH_CIDR=""
      ;;
  esac

  if [ -n "$SESSION_SSH_CIDR" ]; then
    info "SSH will be allowed from: $(yellow "$SESSION_SSH_CIDR")"
    export TF_VAR_allow_ssh_cidr="$SESSION_SSH_CIDR"
  else
    warn "SSH CIDR not set. Scenario default will apply (likely 0.0.0.0/0)."
  fi
}

# ---------- Scenario discovery ----------
scenarios_list() {
  while IFS= read -r dir; do
    local name
    name=$(basename "$dir")
    local desc
    if [ -f "$dir/README.md" ]; then
      desc=$(grep -m 1 '^# ' "$dir/README.md" | sed 's/# //')
    else
      desc="(no description)"
    fi
    printf "  %-25s %s\n" "$name" "$desc"
  done < <(find . -mindepth 2 -maxdepth 2 -type f -name deploy.sh | xargs -n1 dirname | sort -u)
}

get_scenario_names() {
  find . -mindepth 2 -maxdepth 2 -type f -name deploy.sh | xargs -n1 dirname | awk -F/ '{print $2}' | sort | awk '
    BEGIN {
      order[1] = "iam-user-risk"
      order[2] = "dspm-data-generator"
      order[3] = "linux-misconfig-web"
      order[4] = "windows-vuln-iis"
      order[5] = "docker-container-host"
    }
    {
      found[$0] = 1
    }
    END {
      for (i = 1; i <= 5; i++) {
        if (order[i] in found) print order[i]
      }
    }
  '
}

require_scenarios() {
  mapfile -t SCENARIOS < <(get_scenario_names)
  [ "${#SCENARIOS[@]}" -gt 0 ] || error "No deployable scenarios found."
}

# ---------- Logging ----------
logfile_for() {
  local scenario="$1" action="$2"
  printf "%s/%s_%s_%s.log" "$LOG_DIR" "$scenario" "$action" "$(date +%Y%m%d-%H%M%S)"
}

# ---------- Actions ----------
run_deploy() {
  local scenario="$1"
  prompt_for_ssh_cidr
  run_checks

  info "Region: $(yellow "${TF_VAR_region}")"
  if [ -n "${TF_VAR_allow_ssh_cidr:-}" ]; then
    info "SSH CIDR: $(yellow "${TF_VAR_allow_ssh_cidr}")"
  else
    warn "SSH CIDR: using scenario default"
  fi
  
  banner "🚀 Deploying: $scenario"
  local logf; logf="$(logfile_for "$scenario" deploy)"
  info "Logging to $logf"
  
  pushd "$scenario" >/dev/null
  {
    terraform init
    terraform validate
    terraform apply -auto-approve
  } | tee -a "../$logf"
  popd >/dev/null

  banner "✅ Deploy Complete: $scenario"
  info "Public IP: $(terraform -chdir="$scenario" output -raw public_ip 2>/dev/null || echo 'N/A')"
  info "Public DNS: $(terraform -chdir="$scenario" output -raw public_dns 2>/dev/null || echo 'N/A')"
  warn "To delete, run: ./menu.sh --run $scenario teardown"
}

run_teardown() {
  local scenario="$1"
  banner "🗑️ Tearing Down: $scenario"
  local logf; logf="$(logfile_for "$scenario" teardown)"
  info "Logging to $logf"
  if [ ! -f "$scenario/teardown.sh" ]; then
    error "teardown.sh not found in $scenario" "$scenario"
  elif [ ! -x "$scenario/teardown.sh" ]; then
    error "teardown.sh is not executable in $scenario" "$scenario"
  fi
  pushd "$scenario" >/dev/null
  ./teardown.sh | tee -a "../$logf"
  popd >/dev/null
  status "Teardown complete for $scenario."
}

view_info() {
  local scenario="$1"
  if [ -f "$scenario/README.md" ]; then
    banner "📄 README: $scenario"
    less "$scenario/README.md"
  else
    warn "No README.md found in $scenario"
  fi
}

# ---------- Non-interactive ----------
run_noninteractive() {
  local scenario="$1" action="$2"
  require_scenarios
  if ! printf '%s\n' "${SCENARIOS[@]}" | grep -qx "$scenario"; then
    error "Scenario '$scenario' not found."
    info "Available scenarios:"
    scenarios_list
  fi
  case "$action" in
    deploy)   run_deploy "$scenario"   ;;
    teardown) run_teardown "$scenario" ;;
    info)     view_info "$scenario"    ;;
    *) echo "Action must be deploy, teardown, or info"; exit 1 ;;
  esac
}

# ---------- Interactive ----------
show_scenario_descriptions() {
  echo
  info "📋 Available Scenarios (select by number):"
  echo
  
  local i=1
  for scenario in "${SCENARIOS[@]}"; do
    local desc="Description not available"
    local purpose="Purpose not specified"
    local duration="~5-10 min"
    local cost="$0.50-2.00/hour"
    
    case "$scenario" in
      "iam-user-risk")
        desc="IAM User Risk Baseline (CIEM)"
        purpose="Create IAM user with risky configurations: no MFA, multiple access keys, overly broad permissions"
        duration="~2-3 min"
        cost="~$0.10/hour"
        ;;
      "dspm-data-generator")
        desc="Sensitive Data Generation (DSPM)"
        purpose="Generate synthetic PII, PCI, PHI, and secrets data for data security testing"
        duration="~3-5 min"
        cost="~$0.50/hour"
        ;;
      "linux-misconfig-web")
        desc="Linux Web Workload Misconfigurations (CSPM/CDR)"
        purpose="Deploy misconfigured Linux EC2: public access, IMDSv1, unencrypted EBS, outdated OS"
        duration="~5-7 min"
        cost="~$1.00/hour"
        ;;
      "windows-vuln-iis")
        desc="Windows IIS Server Vulnerabilities (CSPM/CDR)"
        purpose="Deploy Windows Server with IIS: public RDP, IMDSv1, unencrypted EBS, web vulnerabilities"
        duration="~8-12 min"
        cost="~$2.00/hour"
        ;;
      "docker-container-host")
        desc="Container & Host Exploitation (CWPP/CSPM)"
        purpose="Deploy risky containerized workload: root container, host mounts, network exposure"
        duration="~6-8 min"
        cost="~$1.50/hour"
        ;;
    esac
    
    printf "$(cyan "$i.")") $(yellow "$scenario")\n"
    printf "   $(green "→") $desc\n"
    printf "   $(blue "Purpose:") $purpose\n"
    printf "   $(magenta "Duration:") $duration  $(magenta "Est. Cost:") $cost\n"
    echo
    ((i++))
  done
  
  printf "$(cyan "$i.")") $(red "Exit")\n"
  echo
  warn "⚠️  These scenarios deploy intentionally vulnerable infrastructure. Use only in non-production AWS accounts."
  echo
}

interactive_menu() {
  require_scenarios
  # Always ensure defaults for TUI display - force override if blank
  if [ -z "$TF_VAR_owner" ]; then
    TF_VAR_owner="aleghari"
    export TF_VAR_owner
  fi
  if [ -z "$TF_VAR_region" ]; then
    TF_VAR_region="us-east-1"
    export TF_VAR_region
  fi

  # Enhanced welcome screen
  echo
  echo "$(cyan "════════════════════════════════════════════════════════════")"
  echo "$(cyan "                ☁️  CNAPP BREACH SIMULATION LAB ☁️               ")"
  echo "$(cyan "                      ctxcloud-testing v1.0                     ")"
  echo "$(cyan "════════════════════════════════════════════════════════════")"
  echo
  info "$(bold "Lab Environment:") AWS CNAPP security testing scenarios"
  info "$(bold "Narrative:") Progressive 5-Act breach simulation chain"
  info "$(bold "Purpose:") Validate detections, train incident response, test CNAPP tools"
  echo
  
  # Configuration display
  local owner_display="${TF_VAR_owner:-aleghari}"
  if [ -z "$owner_display" ]; then owner_display="aleghari"; fi
  local region_display="${TF_VAR_region:-us-east-1}"
  if [ -z "$region_display" ]; then region_display="us-east-1"; fi
  
  info "$(bold "Configuration:")"
  info "  • Owner: $(yellow "$owner_display")"
  info "  • Region: $(yellow "$region_display")"
  [ -n "${TF_VAR_allow_ssh_cidr:-}" ] && info "  • SSH CIDR: $(yellow "$TF_VAR_allow_ssh_cidr")" || info "  • SSH CIDR: $(yellow "Will be configured per scenario")"
  echo
  
  show_scenario_descriptions
  
  PS3="$(blue "▶️  Choose a scenario (1-${#SCENARIOS[@]}) or Exit ($((${#SCENARIOS[@]} + 1))): ")"
  select SCEN in "${SCENARIOS[@]}" "Exit"; do
    if [ "$REPLY" -eq $(( ${#SCENARIOS[@]} + 1 )) ] || [ "$SCEN" = "Exit" ]; then
      status "Goodbye!"
      exit 0
    fi
    [ -n "${SCEN:-}" ] || { warn "Invalid selection"; continue; }

    banner "Selected: $SCEN"
    PS3="$(blue "Choose action for $(cyan "$SCEN"): ")"
    echo
    banner "Selected: $SCEN"
    
    # Show scenario-specific information
    case "$SCEN" in
      "iam-user-risk")
        info "$(bold "Act I:") Identity Compromise - IAM User Risk Baseline"
        info "Creates IAM user with multiple access keys, no MFA, and overly broad permissions"
        ;;
      "dspm-data-generator")
        info "$(bold "Act II:") Sensitive Data Creation - DSPM Data Generator"
        info "Generates synthetic sensitive data (PII, PCI, PHI, secrets) for testing"
        ;;
      "linux-misconfig-web")
        info "$(bold "Act III:") Infrastructure Misconfiguration - Linux Web Server"
        info "Deploys misconfigured Linux EC2 with public access and security gaps"
        ;;
      "windows-vuln-iis")
        info "$(bold "Act IV:") Infrastructure Misconfiguration - Windows IIS Server"
        info "Deploys vulnerable Windows Server with IIS and multiple misconfigurations"
        ;;
      "docker-container-host")
        info "$(bold "Act V:") Container & Host Exploitation - Risky Docker Workload"
        info "Deploys containerized workload with dangerous host access and networking"
        ;;
    esac
    echo
    
    info "$(bold "Available Actions:")"
    echo "  🚀 Deploy   - Create and configure the scenario infrastructure"
    echo "  🗑️  Teardown - Destroy all resources for this scenario"
    echo "  📄 View Info - Read detailed scenario documentation"
    echo "  ⬅️  Back     - Return to scenario selection"
    echo
    
    PS3="$(blue "Choose action for $(cyan "$SCEN"): ")"
    select ACTION in "🚀 Deploy" "🗑️ Teardown" "📄 View Info" "⬅️  Back"; do
      case "$ACTION" in
        "🚀 Deploy")
          echo
          info "$(bold "Preparing to deploy $(cyan "$SCEN")...")"
          info "This will create AWS resources that may incur costs."
          run_deploy "$SCEN"
          echo
          status "$(bold "Deployment Complete!") ✨"
          info "$(bold "Next Steps:")"
          info "  • Review the deployment outputs above"
          info "  • Check scenario README for validation commands"
          info "  • Use your CNAPP tools to detect the misconfigurations"
          info "  • Run teardown when finished to clean up resources"
          echo
          warn "Press Enter to continue..."
          read -r
          break
          ;;
        "🗑️ Teardown")
          echo
          warn "$(bold "⚠️  Preparing to teardown $(cyan "$SCEN")...")"
          warn "This will destroy all AWS resources for this scenario."
          run_teardown "$SCEN"
          echo
          status "$(bold "Teardown Complete!") 🧹"
          echo
          info "Press Enter to continue..."
          read -r
          break
          ;;
        "📄 View Info")
          view_info "$SCEN"
          echo
          info "Press Enter to continue..."
          read -r
          ;;
        "⬅️  Back")
          echo
          show_scenario_descriptions
          break
          ;;
        *) warn "Invalid option. Please select 1-4." ;;
      esac
    done
  done
}

# ---------- CLI ----------
usage() {
  cat <<EOF
Usage: $0 [command]

Commands:
  (no command)      Launch interactive TUI
  --run <s|a> <d|t>   Run non-interactively (scenario, action)
                      s: scenario name, a: all
                      d: deploy, t: teardown
  --scenarios       List available scenarios
  --set <key> <val> Set a variable (region, owner, ssh_cidr)
  -h, --help        Show this help message

Examples:
  ./menu.sh
  ./menu.sh --run linux-misconfig-web deploy
  ./menu.sh --set region eu-west-1
EOF
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    --run) shift; run_noninteractive "${1:-}" "${2:-}";;
    --scenarios) scenarios_list ;;
    --set)
      shift
      local key="${1:-}" val="${2:-}"
      case "$key" in
        region) export TF_VAR_region="$val";  status "Region set to: $(yellow "$val")" ;;
        owner)  export TF_VAR_owner="$val";   status "Owner set to: $(yellow "$val")" ;;
        ssh_cidr)
          export TF_VAR_allow_ssh_cidr="$val"
          SESSION_SSH_CIDR="$val"
          status "SSH CIDR set to: $(yellow "$val")"
          ;;
        *) error "Unknown set key: $key" ;;
      esac
      ;;
    "" ) run_checks; interactive_menu ;;
    -h|--help) usage ;;
    * ) error "Unknown command: $cmd"; usage ;;
  esac
}
main "$@"
