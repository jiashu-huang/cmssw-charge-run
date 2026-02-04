#!/bin/bash
set -euo pipefail

################################################################################
#
# submit_all_jobs.sh
# Submit all Condor jobs under a job root.
# Jiashu Huang + Codex (2026-02-03)
#
################################################################################

usage() {
  cat <<'USAGE'
Usage: submit_all_jobs.sh [--dry-run|--manual] <job_root>

Arguments:
  job_root  Parent directory containing batch job folders

Behavior:
  Finds all my_job.job files and submits them from the repo root.
USAGE
}

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ] || [ "${1:-}" = "--manual" ]; then
  DRY_RUN=1
  shift
fi

JOB_ROOT=${1:-}
if [ -z "$JOB_ROOT" ]; then
  usage
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

JOB_ROOT_ABS=$(cd "$JOB_ROOT" && pwd)

mapfile -t JOB_FILES < <(find "$JOB_ROOT_ABS" -name my_job.job | sort)
if [ ${#JOB_FILES[@]} -eq 0 ]; then
  echo "ERROR: No my_job.job files found under: $JOB_ROOT_ABS" >&2
  exit 1
fi

cd "$REPO_ROOT"

for job in "${JOB_FILES[@]}"; do
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
