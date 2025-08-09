#!/usr/bin/env bash
# menu.sh — ctxcloud-testing TUI
set -euo pipefail

# ---------- Defaults ----------
export TF_VAR_region="${TF_VAR_region:-us-east-1}"
export TF_VAR_owner="${TF_VAR_owner:-aleghari}"
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
error() { red; echo "❌ $1"; r; exit 1; }
info() { blue; echo "ℹ️  $1"; r; }

# ---------- Preflight checks ----------
run_checks() {
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
    read -r -p "Use $(yellow "$detected/32") for SSH? [$(green Y)es/$(red n)o/$(cyan c)ustom/$(magenta s)kip] " choice
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
  find . -mindepth 2 -maxdepth 2 -type f -name deploy.sh | xargs -n1 dirname | awk -F/ '{print $2}' | sort -u
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
  if [ ! -x "$scenario/teardown.sh" ]; then
    error "No executable teardown.sh found in $scenario"
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
interactive_menu() {
  require_scenarios
  echo
  banner "☁️ Cortex Cloud CNAPP Lab ☁️"
  info "Owner: $(yellow "$TF_VAR_owner")   Region: $(yellow "$TF_VAR_region")"
  [ -n "${TF_VAR_allow_ssh_cidr:-}" ] && info "SSH CIDR: $(yellow "$TF_VAR_allow_ssh_cidr")"
  
  PS3="$(blue '▶️  Choose a scenario: ')"
  select SCEN in "${SCENARIOS[@]}" "Exit"; do
    if [ "$REPLY" -eq $(( ${#SCENARIOS[@]} + 1 )) ] || [ "$SCEN" = "Exit" ]; then
      status "Goodbye!"
      exit 0
    fi
    [ -n "${SCEN:-}" ] || { warn "Invalid selection"; continue; }

    banner "Selected: $SCEN"
    PS3="$(blue "Choose action for $(cyan "$SCEN"): ")"
    select ACTION in "🚀 Deploy" "🗑️ Teardown" "📄 View Info" "⬅️  Back"; do
      case "$ACTION" in
        "🚀 Deploy") run_deploy "$SCEN"; break ;;
        "🗑️ Teardown") run_teardown "$SCEN"; break ;;
        "📄 View Info") view_info "$SCEN" ;;
        "⬅️  Back") echo; break ;;
        *) warn "Invalid option" ;;
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
