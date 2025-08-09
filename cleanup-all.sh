#!/usr/bin/env bash
# cleanup-all.sh — Destroy all scenarios in ctxcloud-testing

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"

green() { tput setaf 2 2>/dev/null || true; }
yellow() { tput setaf 3 2>/dev/null || true; }
red() { tput setaf 1 2>/dev/null || true; }
cyan() { tput setaf 6 2>/dev/null || true; }
resetc() { tput sgr0 2>/dev/null || true; }
status() { green; echo "✅ $1"; resetc; }
warn() { yellow; echo "⚠️  $1"; resetc; }
error() { red; echo "❌ $1"; resetc; exit 1; }
info() { cyan; echo "ℹ️  $1"; resetc; }

CONFIRM_RUN=true
if [[ "${1:-}" == "--yes" ]]; then
  CONFIRM_RUN=false
fi

if $CONFIRM_RUN; then
  read -r -p "$(yellow)⚠️  This will teardown ALL scenarios. Continue? (y/N)$(resetc) " choice
  [[ "${choice,,}" == "y" || "${choice,,}" == "yes" ]] || { warn "Aborted."; exit 0; }
fi

COUNT=0
for SCENARIO in "$ROOT_DIR"/*/; do
    if [[ -x "${SCENARIO}teardown.sh" ]]; then
        NAME=$(basename "$SCENARIO")
        info "🗑️  Tearing down $NAME..."
        (
            cd "$SCENARIO"
            ./teardown.sh | tee -a "$LOG_DIR/${NAME}_teardown_$(date +%Y%m%d_%H%M%S).log"
        )
        ((COUNT++))
    fi
done

status "All scenarios cleaned up."
info "Total scenarios removed: $COUNT"
