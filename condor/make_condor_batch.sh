#!/bin/bash
set -euo pipefail

################################################################################
#
# make_condor_batch.sh
# Create a job folder with a runner .sh and a Condor .job file.
# Jiashu Huang (2026-01-27)
#
################################################################################

usage() {
  cat <<'USAGE'
Usage: make_condor_batch.sh [--output-root-dir DIR] <input_list.txt> <job_dir>

Arguments:
  input_list.txt  Text file with one input ROOT path per line
  job_dir         Destination folder for the generated .sh and .job

Options:
  --output-root-dir DIR  Directory where output ROOT files will be written

USAGE
}

OUTPUT_ROOT_DIR_ARG=""
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-root-dir)
      if [ $# -lt 2 ]; then
        echo "ERROR: --output-root-dir requires a value" >&2
        exit 1
      fi
      OUTPUT_ROOT_DIR_ARG="$2"
      shift 2
      ;;
    --output-root-dir=*)
      OUTPUT_ROOT_DIR_ARG="${1#*=}"
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

INPUT_LIST=${1:-}
JOB_DIR=${2:-}

# Validate required arguments.
if [ -z "$INPUT_LIST" ] || [ -z "$JOB_DIR" ]; then
  usage
  exit 1
fi

# Ensure the input list exists before we proceed.
if [ ! -f "$INPUT_LIST" ]; then
  echo "ERROR: Input list not found: $INPUT_LIST" >&2
  exit 1
fi

# Create or validate the job directory.
if [ ! -d "$JOB_DIR" ]; then
  mkdir -p "$JOB_DIR"
fi

# Resolve script and repo paths so this works from any working directory.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
JOB_DIR_ABS=$(cd "$JOB_DIR" && pwd)

# Resolve output ROOT directory (default: job folder).
if [ -z "$OUTPUT_ROOT_DIR_ARG" ]; then
  OUTPUT_ROOT_DIR_ABS="$JOB_DIR_ABS"
elif [[ "$OUTPUT_ROOT_DIR_ARG" = /* ]]; then
  OUTPUT_ROOT_DIR_ABS="$OUTPUT_ROOT_DIR_ARG"
else
  OUTPUT_ROOT_DIR_ABS="$REPO_ROOT/$OUTPUT_ROOT_DIR_ARG"
fi

# Condor submit files are assumed to be submitted from the repo root.
# Use a path that resolves correctly from $REPO_ROOT.
if [[ "$JOB_DIR_ABS" == "$REPO_ROOT" ]]; then
  SUBMIT_JOB_DIR="."
elif [[ "$JOB_DIR_ABS" == "$REPO_ROOT/"* ]]; then
  SUBMIT_JOB_DIR="./${JOB_DIR_ABS#$REPO_ROOT/}"
else
  SUBMIT_JOB_DIR="$JOB_DIR_ABS"
fi

# Copy the input list into the job directory for reproducibility.
JOB_INPUT_LIST="$JOB_DIR_ABS/input_list.txt"
cp "$INPUT_LIST" "$JOB_INPUT_LIST"

# Output artifacts created by this script.
RUN_SH="$JOB_DIR_ABS/my_exec.sh"
JOB_FILE="$JOB_DIR_ABS/my_job.job"

# Write the per-job runner script.
# This script invokes the repo's run_batch_cmsrun.sh with fixed inputs.
cat <<EOF > "$RUN_SH"
#!/bin/bash
set -euo pipefail

# Absolute repo path captured at creation time.
REPO_ROOT="$REPO_ROOT"
# The copied input list lives alongside this script.
INPUT_LIST="$JOB_INPUT_LIST"
# Write output ROOT files into the configured output directory.
OUTPUT_ROOT_DIR="$OUTPUT_ROOT_DIR_ABS"
# Store generated configs under a timestamped subfolder within the job folder.
CFG_BASE_DIR="$JOB_DIR_ABS/cms_cfgs"
# Allow override for CMSSW source; otherwise use the repo-adjacent default.
CMSSW_SRC_DIR="\${CMSSW_SRC_DIR:-$REPO_ROOT/../CMSSW_15_1_0_patch4/src}"

# Ensure output folders exist before running.
mkdir -p "\$OUTPUT_ROOT_DIR" "\$CFG_BASE_DIR"

# Run the batch helper: generate cfgs + run cmsRun per file.
"\$REPO_ROOT/condor/run_batch_cmsrun.sh" "\$INPUT_LIST" "\$OUTPUT_ROOT_DIR" "\$CMSSW_SRC_DIR" "\$CFG_BASE_DIR"
EOF

# Ensure the runner script is executable for Condor.
chmod +x "$RUN_SH"

# Write the Condor job description file.
cat <<EOF > "$JOB_FILE"
universe              = vanilla
executable            = ${SUBMIT_JOB_DIR}/my_exec.sh
initialdir            = ${SUBMIT_JOB_DIR}
getenv                = true

# Write logs into the same folder with job/processor stamping.
log                   = ${SUBMIT_JOB_DIR}/\$(Cluster).\$(Process).log
output                = ${SUBMIT_JOB_DIR}/\$(Cluster).\$(Process).out
error                 = ${SUBMIT_JOB_DIR}/\$(Cluster).\$(Process).err

# Resource requests; tune as needed.
request_cpus          = 2
request_memory        = 8G
request_disk          = 4G

queue
EOF

# Final summary for the user.
echo "Wrote runner: $RUN_SH"
echo "Wrote job   : $JOB_FILE"
echo "Input list  : $JOB_INPUT_LIST"
echo "Output ROOT : $OUTPUT_ROOT_DIR_ABS"
