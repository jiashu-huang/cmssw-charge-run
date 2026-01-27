#!/bin/bash
set -euo pipefail

################################################################################
#
# run_batch_cmsrun.sh
# Generate per-file CMSSW configs from a list and run cmsRun on each.
# Jiashu Huang (2026-01-27)
#
################################################################################

usage() {
  cat <<'USAGE'
Usage: run_batch_cmsrun.sh [--dry-run|--manual] <input_list.txt> <output_root_dir> [cmssw_src_dir] [cfg_base_dir]

Arguments:
  input_list.txt   Text file with one input ROOT path per line
  output_root_dir  Directory where output ROOT files will be written
  cmssw_src_dir    Path to CMSSW src directory (default: ../../CMSSW_15_1_0_patch4/src)
  cfg_base_dir     Base directory to place generated configs (default: ../cms_cfgs)

Behavior:
  Creates a timestamped config folder: <cfg_base_dir>/<YYYYmmdd_HHMMSS>/
  For each input line, generates a config via generate_config.py and runs cmsRun.
  With --dry-run/--manual, configs are generated but cmsRun is not executed.
USAGE
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ] || [ "${1:-}" = "--manual" ]; then
  DRY_RUN=1
  shift
fi

INPUT_LIST=${1:-}
OUTPUT_ROOT_DIR=${2:-}
CMSSW_SRC_DIR=${3:-"$SCRIPT_DIR/../../CMSSW_15_1_0_patch4/src"}
CFG_BASE_DIR=${4:-"$REPO_ROOT/cms_cfgs"}

if [ -z "$INPUT_LIST" ] || [ -z "$OUTPUT_ROOT_DIR" ]; then
  usage
  exit 1
fi

if [ ! -f "$INPUT_LIST" ]; then
  echo "ERROR: Input list not found: $INPUT_LIST" >&2
  exit 1
fi

if [ ! -d "$CMSSW_SRC_DIR" ]; then
  echo "ERROR: CMSSW src directory not found: $CMSSW_SRC_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_ROOT_DIR"
if [ ! -w "$OUTPUT_ROOT_DIR" ]; then
  echo "ERROR: Output directory is not writable: $OUTPUT_ROOT_DIR" >&2
  exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CFG_DIR="$CFG_BASE_DIR/$TIMESTAMP"
mkdir -p "$CFG_DIR"

echo "Input list     : $INPUT_LIST"
echo "Output ROOT dir: $OUTPUT_ROOT_DIR"
echo "CMSSW src dir  : $CMSSW_SRC_DIR"
echo "Config dir     : $CFG_DIR"
echo "Dry-run        : $DRY_RUN"
echo ""

if [ "$DRY_RUN" -eq 0 ]; then
  # Set up CMSSW environment
  set +u
  source /cvmfs/cms.cern.ch/cmsset_default.sh
  set -u
  cd "$CMSSW_SRC_DIR"
  eval "$(scramv1 runtime -sh)"
  cd "$REPO_ROOT"
fi

GENERATOR="$SCRIPT_DIR/generate_config.py"
if [ ! -x "$GENERATOR" ] && [ ! -f "$GENERATOR" ]; then
  echo "ERROR: generate_config.py not found: $GENERATOR" >&2
  exit 1
fi

while IFS= read -r line || [ -n "$line" ]; do
  # Trim whitespace
  path=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "$path" ] || [[ "$path" == \#* ]]; then
    continue
  fi

  base=$(basename "$path")
  if [[ "$base" == *.root ]]; then
    base="${base%.root}"
  fi

  cfg_path="$CFG_DIR/${base}_cfg.py"

  python3 "$GENERATOR" "$path" "$CFG_DIR" "$OUTPUT_ROOT_DIR"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry-run: cmsRun $cfg_path"
  else
    echo "Running: cmsRun $cfg_path"
    cmsRun "$cfg_path"
  fi
done < "$INPUT_LIST"
