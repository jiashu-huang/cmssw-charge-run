#!/bin/bash
set -euo pipefail

################################################################################
#
# cmssw_precheck.sh
# Ensure CMSSW release exists and load its runtime environment.
#
# Usage (recommended):
#   source ./cmssw_precheck.sh [cmssw_src_dir]
#
################################################################################

CMSSW_SRC_DIR=${1:-"../CMSSW_15_1_0_patch4/src"}

if [ ! -d "$CMSSW_SRC_DIR" ]; then
  echo "ERROR: CMSSW src directory not found: $CMSSW_SRC_DIR" >&2
  return 1 2>/dev/null || exit 1
fi

# Warn if not sourced (environment won't persist).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "WARNING: Run this script with 'source ./cmssw_precheck.sh' to keep the environment." >&2
fi

# Set up the CMS environment.
set +u
source /cvmfs/cms.cern.ch/cmsset_default.sh
set -u

# Load CMSSW runtime.
pushd "$CMSSW_SRC_DIR" >/dev/null
if ! command -v scramv1 >/dev/null 2>&1; then
  echo "ERROR: scramv1 not found after cmsset_default.sh" >&2
  popd >/dev/null
  return 1 2>/dev/null || exit 1
fi

eval "$(scramv1 runtime -sh)"
popd >/dev/null

echo "CMSSW environment loaded from: $CMSSW_SRC_DIR"
