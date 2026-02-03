#!/bin/bash
set -euo pipefail

################################################################################
#
# batch_dataset.sh
# Wrapper for batch_dataset.py that ensures CMSSW env is loaded.
#
# Usage:
#   ./condor/batch_dataset.sh --dataset <DATASET> [--batch-size N] [--out-base DIR] \
#     [--output-root-base DIR] [--job-root DIR] [--cmssw-src-dir DIR] [--sample-cfg FILE]
#
################################################################################

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# Allow override via environment; default to repo-adjacent CMSSW release.
CMSSW_SRC_DIR=${CMSSW_SRC_DIR:-"$REPO_ROOT/../CMSSW_15_1_0_patch4/src"}
export CMSSW_SRC_DIR

# Load CMSSW runtime (sets up dasgoclient PATH).
source "$REPO_ROOT/cmssw_precheck.sh" "$CMSSW_SRC_DIR"

# Ensure a valid VOMS proxy exists (prompts if missing/expired).
source "$REPO_ROOT/proxy_precheck.sh"

# Pass proxy path into metadata unless the user already provided one.
PROXY_ARG=()
if [ -n "${X509_USER_PROXY:-}" ]; then
  HAS_PROXY_ARG=0
  for arg in "$@"; do
    case "$arg" in
      --proxy-path|--proxy-path=*)
        HAS_PROXY_ARG=1
        break
        ;;
    esac
  done
  if [ "$HAS_PROXY_ARG" -eq 0 ]; then
    PROXY_ARG=(--proxy-path "$X509_USER_PROXY")
  fi
fi

exec python3 "$SCRIPT_DIR/batch_dataset.py" "${PROXY_ARG[@]}" "$@"
