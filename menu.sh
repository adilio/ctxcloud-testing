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
magenta() { c 5; }
cyan() { c 6; }
white() { c 7; }

banner() {
  echo
  cyan; bold; echo "====== $1 ======"; r;
  echo
}

status() { green; echo "✅ $1"; r; }
warn() { yellow; echo "⚠️  $1"; r; }
error() {
  local msg="$1"
  local scenario_path="${2:-}"
  red; echo "❌ $msg"; r;
  echo
  echo "💡 Troubleshooting Tips:"
  case "$msg" in
    *"Terraform not installed"*)
      echo "  • Download from: https://developer.hashicorp.com/terraform/downloads"
      echo "  • On macOS: brew install terraform"
      echo "  • Verify installation: terraform --version"
      ;;
    *"AWS CLI not installed"*)
      echo "  • Download from: https://aws.amazon.com/cli/"
      echo "  • On macOS: brew install awscli"
      echo "  • Verify installation: aws --version"
      ;;
    *"AWS credentials invalid"*)
      echo "  • Run: aws configure"
      echo "  • Ensure you have programmatic access keys"
      echo "  • Test with: aws sts get-caller-identity"
      echo "  • Check region availability: aws ec2 describe-regions"
      ;;
    *"No executable teardown.sh"*)
      if [ -n "$scenario_path" ]; then
        echo "  • Check if the file exists: ls -la \"$scenario_path\"/teardown.sh"
        echo "  • Make executable: chmod +x \"$scenario_path\"/teardown.sh"
      fi
      echo "  • Or use the .sh permissions prompt at startup"
      ;;
    *)
      echo "  • Check the logs directory for detailed error information"
      echo "  • Ensure you're running in the correct directory"
      echo "  • Verify AWS permissions for EC2, IAM, and S3 operations"
      ;;
  esac
  echo
  exit 1
}
info() { echo "$1"; }

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
  echo "Running preflight checks..."
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
    echo "Detected public IP: $detected"
    echo "Use $detected/32 for SSH? Press Enter (default: 0.0.0.0/0) or [Y] to accept detected / [N]o / [C]ustom / [S]kip"
    read -r -p "Choice: " choice
  else
    warn "Could not detect your public IP automatically."
    read -r -p "Enter custom CIDR (e.g., 198.51.100.42/32), or press Enter to skip: " custom
    choice="c"
  fi

  case "${choice,,}" in
    ""|"y"|"yes")
      if [ -n "$detected" ]; then
        # Default to open SSH if user just presses Enter (empty input)
        if [ -z "$choice" ]; then
          SESSION_SSH_CIDR="0.0.0.0/0"
        else
          SESSION_SSH_CIDR="${detected}/32"
        fi
        export TF_VAR_allow_ssh_cidr="$SESSION_SSH_CIDR"
      else
        SESSION_SSH_CIDR=""
      fi
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
    export TF_VAR_allow_ssh_cidr="$SESSION_SSH_CIDR"
    # Removed echo to prevent blank message in scenarios not needing SSH
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

  # Skip SSH CIDR prompt for scenarios without EC2 instances
  case "$scenario" in
    "iam-user-risk"|"dspm-data-generator")
      warn "Skipping SSH CIDR prompt — scenario does not create EC2 instances."
      ;;
    *)
      prompt_for_ssh_cidr
      ;;
  esac
  run_checks

  # Removed Region/SSH CIDR runtime echo to avoid blank outputs for all scenarios
  
  banner "🚀 Deploying: $scenario"
  local logf; logf="$(logfile_for "$scenario" deploy)"
  echo "Logging to $logf"
  
  # Ensure Terraform state and .terraform dir are preserved between runs
  mkdir -p "$scenario/.terraform"
  touch "$scenario/terraform.tfstate" "$scenario/terraform.tfstate.backup"

  pushd "$scenario" >/dev/null
  {
    terraform init
    terraform validate
    terraform apply -auto-approve
  } | tee -a "../$logf"
  popd >/dev/null

  banner "✅ Deploy Complete: $scenario"
  terraform -chdir="$scenario" output -json | jq -r 'to_entries[] | "\(.key) = \(.value.value)"'
  if terraform -chdir="$scenario" output -raw public_ip >/dev/null 2>&1; then
    echo "Public IP: $(terraform -chdir="$scenario" output -raw public_ip)"
  else
    echo "Public IP: Not applicable (no EC2 instance in this scenario)"
  fi
  if terraform -chdir="$scenario" output -raw public_dns >/dev/null 2>&1; then
    echo "Public DNS: $(terraform -chdir="$scenario" output -raw public_dns)"
  else
    echo "Public DNS: Not applicable (no EC2 instance in this scenario)"
  fi
  warn "To delete, run: ./menu.sh --run $scenario teardown"
}

run_teardown() {
  local scenario="$1"
  banner "🗑️ Tearing Down: $scenario"
  local logf; logf="$(logfile_for "$scenario" teardown)"
  echo "Logging to $logf"
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
    echo "Available scenarios:"
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
show_integrated_menu() {
  local i=1
  for scenario in "${SCENARIOS[@]}"; do
    case "$scenario" in
      "iam-user-risk")
        printf "%s%2d.%s %s%-25s%s %s[2-3 min]%s %sAct I: Identity Compromise%s\n" "$(cyan)" "$i" "$(r)" "$(bold)" "$scenario" "$(r)" "$(magenta)" "$(r)" "$(white)" "$(r)"
        printf "     %sCreate IAM user with risky configurations (no MFA, multiple keys)%s\n" "$(white)" "$(r)"
        ;;
      "dspm-data-generator")
        printf "%s%2d.%s %s%-25s%s %s[3-5 min]%s %sAct II: Sensitive Data Creation%s\n" "$(cyan)" "$i" "$(r)" "$(bold)" "$scenario" "$(r)" "$(magenta)" "$(r)" "$(white)" "$(r)"
        printf "     %sGenerate synthetic PII, PCI, PHI, and secrets data for testing%s\n" "$(white)" "$(r)"
        ;;
      "linux-misconfig-web")
        printf "%s%2d.%s %s%-25s%s %s[5-7 min]%s %sAct III: Linux Server Misconfig%s\n" "$(cyan)" "$i" "$(r)" "$(bold)" "$scenario" "$(r)" "$(magenta)" "$(r)" "$(white)" "$(r)"
        printf "     %sDeploy misconfigured Linux EC2 with public access and security gaps%s\n" "$(white)" "$(r)"
        ;;
      "windows-vuln-iis")
        printf "%s%2d.%s %s%-25s%s %s[8-12 min]%s %sAct IV: Windows Server Vulnerabilities%s\n" "$(cyan)" "$i" "$(r)" "$(bold)" "$scenario" "$(r)" "$(magenta)" "$(r)" "$(white)" "$(r)"
        printf "     %sDeploy Windows Server with IIS, public RDP, and web vulnerabilities%s\n" "$(white)" "$(r)"
        ;;
      "docker-container-host")
        printf "%s%2d.%s %s%-25s%s %s[6-8 min]%s %sAct V: Container & Host Exploitation%s\n" "$(cyan)" "$i" "$(r)" "$(bold)" "$scenario" "$(r)" "$(magenta)" "$(r)" "$(white)" "$(r)"
        printf "     %sDeploy risky containerized workload with dangerous host access%s\n" "$(white)" "$(r)"
        ;;
      *)
        printf "$(cyan "%2d.") $(bold "%s")\n" "$i" "$scenario"
        ;;
    esac
    echo
    ((i++))
  done
  printf "%s%2d.%s %sExit%s\n" "$(cyan)" "$i" "$(r)" "$(red)" "$(r)"
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

  # Clean, compact welcome screen
  clear
  cyan; bold; echo "════════════════════════════════════════════════════════════"; r;
  cyan; bold; echo "   ☁️  CNAPP BREACH SIMULATION LAB — ctxcloud-testing v1.0    "; r;
  cyan; bold; echo "════════════════════════════════════════════════════════════"; r;
  echo
  echo "🛡️  Safe AWS lab environment for testing CNAPP security tools"
  echo
  echo "Progressive 5-Act breach simulation scenarios for validation, training,"
  echo "and vulnerability exploration in a controlled environment."
  echo
  yellow; echo "These scenarios deploy intentionally vulnerable infrastructure."; r;
  yellow; echo "Use only in non-production AWS accounts."; r;

  # Custom menu handling to show integrated descriptions
  while true; do
    echo
    show_integrated_menu
    echo
    read -r -p "$(green "Choose a scenario (1-${#SCENARIOS[@]}) or Exit ($((${#SCENARIOS[@]} + 1))): ")" choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      if [ "$choice" -eq $(( ${#SCENARIOS[@]} + 1 )) ]; then
        status "Goodbye!"
        exit 0
      elif [ "$choice" -ge 1 ] && [ "$choice" -le "${#SCENARIOS[@]}" ]; then
        SCEN="${SCENARIOS[$((choice-1))]}"
        
        echo
        banner "Selected: $SCEN"
        
        # Show scenario-specific information
        case "$SCEN" in
          "iam-user-risk")
            echo "$(bold "Act I:") Identity Compromise - IAM User Risk Baseline"
            echo "Creates IAM user with multiple access keys, no MFA, and overly broad permissions"
            ;;
          "dspm-data-generator")
            echo "$(bold "Act II:") Sensitive Data Creation - DSPM Data Generator"
            echo "Generates synthetic sensitive data (PII, PCI, PHI, secrets) for testing"
            ;;
          "linux-misconfig-web")
            echo "$(bold "Act III:") Infrastructure Misconfiguration - Linux Web Server"
            echo "Deploys misconfigured Linux EC2 with public access and security gaps"
            ;;
          "windows-vuln-iis")
            echo "$(bold "Act IV:") Infrastructure Misconfiguration - Windows IIS Server"
            echo "Deploys vulnerable Windows Server with IIS and multiple misconfigurations"
            ;;
          "docker-container-host")
            echo "$(bold "Act V:") Container & Host Exploitation - Risky Docker Workload"
            echo "Deploys containerized workload with dangerous host access and networking"
            ;;
        esac
        
        # Numbered action menu
        echo
        while true; do
          echo "Choose an action:"
          printf "%s1.%s %sDeploy%s    - Create and configure the scenario infrastructure\n" "$(cyan)" "$(r)" "$(bold)" "$(r)"
          printf "%s2.%s %sTeardown%s  - Destroy all resources for this scenario\n" "$(cyan)" "$(r)" "$(bold)" "$(r)"
          printf "%s3.%s %sInfo%s      - Read detailed scenario documentation\n" "$(cyan)" "$(r)" "$(bold)" "$(r)"
          printf "%s4.%s %sBack%s      - Return to scenario selection\n" "$(cyan)" "$(r)" "$(bold)" "$(r)"
          echo
          read -r -p "$(green "Choose action (1-4) for $(cyan "$SCEN"): ")" action_choice
          
          case "$action_choice" in
            "1")
              echo
              echo "$(bold "Preparing to deploy $(cyan "$SCEN")...")"
              echo "This will create AWS resources that may incur costs."
              run_deploy "$SCEN"
              echo
              status "$(bold "Deployment Complete!") ✨"
              echo "$(bold "Next Steps:")"
              echo "  • Review the deployment outputs above"
              echo "  • Check scenario README for validation commands"
              echo "  • Use your CNAPP tools to detect the misconfigurations"
              echo "  • Run teardown when finished to clean up resources"
              echo
              echo "Press Enter to continue..."
              read -r
              break 2
              ;;
            "2")
              echo
              warn "$(bold "Preparing to teardown $(cyan "$SCEN")...")"
              echo "This will destroy all AWS resources for this scenario."
              run_teardown "$SCEN"
              echo
              status "$(bold "Teardown Complete!") 🧹"
              echo
              echo "Press Enter to continue..."
              read -r
              break 2
              ;;
            "3")
              view_info "$SCEN"
              echo
              echo "Press Enter to continue..."
              read -r
              break
              ;;
            "4")
              break
              ;;
            *) warn "Invalid selection. Please choose 1-4" ;;
          esac
        done
      else
        warn "Invalid selection. Please choose 1-$((${#SCENARIOS[@]} + 1))"
      fi
    else
      warn "Please enter a number."
    fi
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
        *) error "Unknown set key: $key" "" ;;
      esac
      ;;
    "" ) run_checks; interactive_menu ;;
    -h|--help) usage ;;
    * ) error "Unknown command: $cmd"; usage ;;
  esac
}
main "$@"