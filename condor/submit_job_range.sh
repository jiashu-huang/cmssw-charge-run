#!/bin/bash
set -euo pipefail

################################################################################
#
# submit_job_range.sh
# Submit Condor jobs from batch_FIRST to batch_LAST under a job root.
# Jiashu Huang + Codex (2026-02-05)
#
################################################################################

usage() {
  cat <<'USAGE'
Usage: submit_job_range.sh [--dry-run|--manual] --first N --last N <job_root>

Arguments:
  --first N   First batch index to submit (inclusive)
  --last N    Last batch index to submit (inclusive)
  job_root   Parent directory containing batch job folders

Behavior:
  If <job_root>/condor-jobs exists, jobs are read from that subfolder.
  Each batch_XXX directory is expected to contain exactly one .job file.
USAGE
}

DRY_RUN=0
FIRST=""
LAST=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|--manual)
      DRY_RUN=1
      shift
      ;;
    --first)
      if [ -z "${2:-}" ] || [[ "${2:-}" == --* ]]; then
        echo "ERROR: --first requires a value" >&2
        usage
        exit 1
      fi
      FIRST="$2"
      shift 2
      ;;
    --last)
      if [ -z "${2:-}" ] || [[ "${2:-}" == --* ]]; then
        echo "ERROR: --last requires a value" >&2
        usage
        exit 1
      fi
      LAST="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
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

if [ ${#POSITIONAL[@]} -ne 1 ]; then
  usage
  exit 1
fi

JOB_ROOT=${POSITIONAL[0]}

if [ -z "$FIRST" ] || [ -z "$LAST" ]; then
  echo "ERROR: --first and --last are required" >&2
  usage
  exit 1
fi

if ! [[ "$FIRST" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --first must be a non-negative integer" >&2
  exit 1
fi

if ! [[ "$LAST" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --last must be a non-negative integer" >&2
  exit 1
fi

FIRST_NUM=$((10#$FIRST))
LAST_NUM=$((10#$LAST))

if (( FIRST_NUM > LAST_NUM )); then
  echo "ERROR: --first must be <= --last" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# Ensure a valid VOMS proxy exists before submitting (required for /store access).
source "$REPO_ROOT/proxy_precheck.sh"

if [ ! -d "$JOB_ROOT" ]; then
  echo "ERROR: job_root not found: $JOB_ROOT" >&2
  exit 1
fi

if [ -d "$JOB_ROOT/condor-jobs" ]; then
  JOB_ROOT="$JOB_ROOT/condor-jobs"
fi

JOB_ROOT_ABS=$(cd "$JOB_ROOT" && pwd)

entries=()
found_indices=()

while IFS= read -r dir; do
  batch_name=$(basename "$dir")
  suffix=${batch_name#batch_}
  if [[ ! "$suffix" =~ ^[0-9]+$ ]]; then
    echo "Skipping: $batch_name (non-numeric suffix)" >&2
    continue
  fi

  idx=$((10#$suffix))
  if (( idx < FIRST_NUM || idx > LAST_NUM )); then
    continue
  fi

  mapfile -t job_files < <(find "$dir" -maxdepth 1 -type f -name "*.job" | sort)
  if [ ${#job_files[@]} -eq 0 ]; then
    echo "ERROR: No .job file found in $dir" >&2
    exit 1
  fi
  if [ ${#job_files[@]} -gt 1 ]; then
    echo "ERROR: Multiple .job files found in $dir" >&2
    printf '  %s\n' "${job_files[@]}" >&2
    exit 1
  fi

  entries+=("$idx|${job_files[0]}")
  found_indices+=("$idx")
done < <(find "$JOB_ROOT_ABS" -maxdepth 1 -type d -name "batch_*" | sort -V)

if [ ${#entries[@]} -eq 0 ]; then
  echo "ERROR: No batch directories with .job files found in range $FIRST_NUM..$LAST_NUM under: $JOB_ROOT_ABS" >&2
  exit 1
fi

# Warn on missing batch indices in the requested range.
declare -A found_map
for idx in "${found_indices[@]}"; do
  found_map[$idx]=1
done

missing=()
for ((i = FIRST_NUM; i <= LAST_NUM; i++)); do
  if [ -z "${found_map[$i]:-}" ]; then
    missing+=("$i")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "WARNING: Missing batch directories for indices: ${missing[*]}" >&2
fi

IFS=$'\n' sorted_entries=($(printf '%s\n' "${entries[@]}" | sort -t'|' -k1,1n))
unset IFS

cd "$REPO_ROOT"

for entry in "${sorted_entries[@]}"; do
  job=${entry#*|}
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry-run: condor_submit $job"
  else
    echo "Submitting: $job"
    condor_submit "$job"
  fi
  echo ""
done

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry-run complete. No submissions were made."
fi
