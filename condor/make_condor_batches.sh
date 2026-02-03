#!/bin/bash
set -euo pipefail

################################################################################
#
# make_condor_batches.sh
# Create per-batch Condor jobs from a batch directory.
# Jiashu Huang + Codex (2026-02-03)
#
################################################################################

usage() {
  cat <<'USAGE'
Usage: make_condor_batches.sh <batch_dir|dataset_dir> [--job-root DIR] [--output-root-base DIR] [--cmssw-src-dir DIR] [--sample-cfg FILE] [--proxy-path FILE]

Arguments:
  batch_dir         Directory containing batch_*.txt files (from batch_dataset.py)
                    Or a dataset directory that contains a batches/ subfolder

Behavior:
  Creates job folders directly under <job_root>/<batch_xxx>/.
  Writes output ROOTs under <output_root_base>/<batch_xxx>/ when <output_root_base> is inside the dataset dir,
  otherwise under <output_root_base>/<dataset>/<batch_xxx>/.
USAGE
}

JOB_ROOT=""
OUTPUT_ROOT_BASE=""
CMSSW_SRC_DIR=""
SAMPLE_CFG=""
PROXY_PATH=""
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --job-root)
      if [ $# -lt 2 ]; then
        echo "ERROR: --job-root requires a value" >&2
        exit 1
      fi
      JOB_ROOT="$2"
      shift 2
      ;;
    --job-root=*)
      JOB_ROOT="${1#*=}"
      shift
      ;;
    --output-root-base)
      if [ $# -lt 2 ]; then
        echo "ERROR: --output-root-base requires a value" >&2
        exit 1
      fi
      OUTPUT_ROOT_BASE="$2"
      shift 2
      ;;
    --output-root-base=*)
      OUTPUT_ROOT_BASE="${1#*=}"
      shift
      ;;
    --cmssw-src-dir)
      if [ $# -lt 2 ]; then
        echo "ERROR: --cmssw-src-dir requires a value" >&2
        exit 1
      fi
      CMSSW_SRC_DIR="$2"
      shift 2
      ;;
    --cmssw-src-dir=*)
      CMSSW_SRC_DIR="${1#*=}"
      shift
      ;;
    --sample-cfg)
      if [ $# -lt 2 ]; then
        echo "ERROR: --sample-cfg requires a value" >&2
        exit 1
      fi
      SAMPLE_CFG="$2"
      shift 2
      ;;
    --sample-cfg=*)
      SAMPLE_CFG="${1#*=}"
      shift
      ;;
    --proxy-path)
      if [ $# -lt 2 ]; then
        echo "ERROR: --proxy-path requires a value" >&2
        exit 1
      fi
      PROXY_PATH="$2"
      shift 2
      ;;
    --proxy-path=*)
      PROXY_PATH="${1#*=}"
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
POSITIONAL+=("$@")
set -- "${POSITIONAL[@]}"

BATCH_DIR=${1:-}
if [ -z "$BATCH_DIR" ]; then
  usage
  exit 1
fi

if [ ! -d "$BATCH_DIR" ]; then
  echo "ERROR: batch_dir not found: $BATCH_DIR" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

BATCH_DIR_ABS=$(cd "$BATCH_DIR" && pwd)

# Accept either dataset_dir or batches/ dir.
if ls "$BATCH_DIR_ABS"/batch_*.txt >/dev/null 2>&1; then
  if [ "$(basename "$BATCH_DIR_ABS")" = "batches" ]; then
    DATASET_DIR=$(cd "$BATCH_DIR_ABS/.." && pwd)
  else
    DATASET_DIR="$BATCH_DIR_ABS"
  fi
  BATCHES_DIR="$BATCH_DIR_ABS"
elif [ -d "$BATCH_DIR_ABS/batches" ] && ls "$BATCH_DIR_ABS/batches"/batch_*.txt >/dev/null 2>&1; then
  DATASET_DIR="$BATCH_DIR_ABS"
  BATCHES_DIR="$BATCH_DIR_ABS/batches"
else
  echo "ERROR: No batch_*.txt files found in $BATCH_DIR_ABS or $BATCH_DIR_ABS/batches" >&2
  exit 1
fi

DATASET_NAME=$(basename "$DATASET_DIR")

read_meta() {
  local key="$1"
  local meta_file="$2"
  awk -F': ' -v k="$key" '$1==k {print $2; exit}' "$meta_file"
}

resolve_path() {
  local path="$1"
  if [ -z "$path" ]; then
    echo ""
    return
  fi
  if [[ "$path" = /* ]]; then
    echo "$path"
  else
    echo "$REPO_ROOT/$path"
  fi
}

META_FILE="$DATASET_DIR/metadata.txt"
if [ -f "$META_FILE" ]; then
  META_OUTPUT_ROOT_BASE=$(read_meta "output_root_base" "$META_FILE")
  META_JOB_ROOT=$(read_meta "job_root" "$META_FILE")
  META_CMSSW_SRC_DIR=$(read_meta "cmssw_src_dir" "$META_FILE")
  META_SAMPLE_CFG=$(read_meta "sample_cfg" "$META_FILE")
  META_PROXY_PATH=$(read_meta "proxy_path" "$META_FILE")
fi

if [ -z "$OUTPUT_ROOT_BASE" ] && [ -n "${META_OUTPUT_ROOT_BASE:-}" ]; then
  OUTPUT_ROOT_BASE="$META_OUTPUT_ROOT_BASE"
fi
if [ -z "$JOB_ROOT" ] && [ -n "${META_JOB_ROOT:-}" ]; then
  JOB_ROOT="$META_JOB_ROOT"
fi
if [ -z "$CMSSW_SRC_DIR" ] && [ -n "${META_CMSSW_SRC_DIR:-}" ]; then
  CMSSW_SRC_DIR="$META_CMSSW_SRC_DIR"
fi
if [ -z "$SAMPLE_CFG" ] && [ -n "${META_SAMPLE_CFG:-}" ]; then
  SAMPLE_CFG="$META_SAMPLE_CFG"
fi
if [ -z "$PROXY_PATH" ] && [ -n "${META_PROXY_PATH:-}" ]; then
  PROXY_PATH="$META_PROXY_PATH"
fi

if [ -z "$OUTPUT_ROOT_BASE" ]; then
  OUTPUT_ROOT_BASE=$(cd "$DATASET_DIR/.." && pwd)
fi
if [ -z "$JOB_ROOT" ]; then
  JOB_ROOT="$DATASET_DIR/condor-jobs"
fi

OUTPUT_ROOT_BASE=$(resolve_path "$OUTPUT_ROOT_BASE")
JOB_ROOT=$(resolve_path "$JOB_ROOT")
CMSSW_SRC_DIR=$(resolve_path "$CMSSW_SRC_DIR")
SAMPLE_CFG=$(resolve_path "$SAMPLE_CFG")
PROXY_PATH=$(resolve_path "$PROXY_PATH")

is_within_dataset() {
  case "$1" in
    "$DATASET_DIR" | "$DATASET_DIR"/*) return 0 ;;
    *) return 1 ;;
  esac
}

JOB_DATASET_DIR="$JOB_ROOT"

if is_within_dataset "$OUTPUT_ROOT_BASE"; then
  OUTPUT_DATASET_DIR="$OUTPUT_ROOT_BASE"
else
  OUTPUT_DATASET_DIR="$OUTPUT_ROOT_BASE/$DATASET_NAME"
fi

mkdir -p "$JOB_DATASET_DIR" "$OUTPUT_DATASET_DIR"

mapfile -t BATCH_FILES < <(ls "$BATCHES_DIR"/batch_*.txt 2>/dev/null | sort)
if [ ${#BATCH_FILES[@]} -eq 0 ]; then
  echo "ERROR: No batch_*.txt files found in $BATCHES_DIR" >&2
  exit 1
fi

for batch_file in "${BATCH_FILES[@]}"; do
  # Each batch_file is passed to make_condor_batch.sh, which copies it into the job
  # folder as input_list.txt and the runner uses that copied file.
  batch_name=$(basename "$batch_file" .txt)
  job_dir="$JOB_DATASET_DIR/$batch_name"
  output_dir="$OUTPUT_DATASET_DIR/$batch_name"

  CMD=("$SCRIPT_DIR/make_condor_batch.sh" "--quiet" "--output-root-dir" "$output_dir")
  if [ -n "$CMSSW_SRC_DIR" ]; then
    CMD+=(--cmssw-src-dir "$CMSSW_SRC_DIR")
  fi
  if [ -n "$SAMPLE_CFG" ]; then
    CMD+=(--sample-cfg "$SAMPLE_CFG")
  fi
  if [ -n "$PROXY_PATH" ]; then
    CMD+=(--proxy-path "$PROXY_PATH")
  fi
  CMD+=("$batch_file" "$job_dir")

  "${CMD[@]}"

done

echo "Done. Job root   : $JOB_DATASET_DIR"
echo "Done. Output root: $OUTPUT_DATASET_DIR"
