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
Usage: run_batch_cmsrun.sh [--dry-run|--manual] [--sample-cfg FILE] <input_list.txt> <output_root_dir> [cmssw_src_dir] [cfg_base_dir]

Arguments:
  input_list.txt   Text file with one input ROOT path per line
  output_root_dir  Directory where output ROOT files will be written
  cmssw_src_dir    Path to CMSSW src directory (default: ../../CMSSW_15_1_0_patch4/src)
  cfg_base_dir     Base directory to place generated configs (default: ../cms_cfgs)
  --sample-cfg     Optional sample_cfg.py path for config generation

Behavior:
  Creates a timestamped config folder: <cfg_base_dir>/<YYYYmmdd_HHMMSS>/
  For each input line, generates a config via generate_config.py and runs cmsRun.
  With --dry-run/--manual, configs are generated but cmsRun is not executed.
USAGE
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

DRY_RUN=0
SAMPLE_CFG=""
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|--manual)
      DRY_RUN=1
      shift
      ;;
    --sample-cfg)
      SAMPLE_CFG=${2:-}
      shift 2
      ;;
    --sample-cfg=*)
      SAMPLE_CFG="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "ERROR: Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL[@]}" "$@"

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

if [ -n "$SAMPLE_CFG" ]; then
  if [[ "$SAMPLE_CFG" != /* ]]; then
    SAMPLE_CFG="$REPO_ROOT/$SAMPLE_CFG"
  fi
  if [ ! -f "$SAMPLE_CFG" ]; then
    echo "ERROR: sample cfg not found: $SAMPLE_CFG" >&2
    exit 1
  fi
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
if [ -n "$SAMPLE_CFG" ]; then
  echo "Sample cfg     : $SAMPLE_CFG"
fi
echo "Dry-run        : $DRY_RUN"
echo ""

if [ "$DRY_RUN" -eq 0 ]; then
  # Set up CMSSW environment (centralized in cmssw_precheck.sh).
  if ! source "$REPO_ROOT/cmssw_precheck.sh" "$CMSSW_SRC_DIR"; then
    echo "ERROR: Failed to load CMSSW environment." >&2
    exit 1
  fi
fi

GENERATOR="$SCRIPT_DIR/generate_config.py"
if [ ! -x "$GENERATOR" ] && [ ! -f "$GENERATOR" ]; then
  echo "ERROR: generate_config.py not found: $GENERATOR" >&2
  exit 1
fi

INPUT_PATHS=()
CFG_PATHS=()
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

  INPUT_PATHS+=("$path")
  CFG_PATHS+=("$CFG_DIR/${base}_cfg.py")
done < "$INPUT_LIST"

if [ "${#INPUT_PATHS[@]}" -eq 0 ]; then
  echo "ERROR: No valid input files found in: $INPUT_LIST" >&2
  exit 1
fi

GEN_ARGS=()
if [ -n "$SAMPLE_CFG" ]; then
  GEN_ARGS+=(--sample "$SAMPLE_CFG")
fi

echo "Generating configs..."
for idx in "${!INPUT_PATHS[@]}"; do
  python3 "$GENERATOR" "${GEN_ARGS[@]}" "${INPUT_PATHS[$idx]}" "$CFG_DIR" "$OUTPUT_ROOT_DIR"
done

if [ "$DRY_RUN" -eq 1 ]; then
  for cfg_path in "${CFG_PATHS[@]}"; do
    echo "Dry-run: cmsRun $cfg_path"
  done
else
  for cfg_path in "${CFG_PATHS[@]}"; do
    echo "Running: cmsRun $cfg_path"
    cmsRun "$cfg_path"
  done
fi
