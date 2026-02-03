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
Usage: make_condor_batch.sh [--quiet] [--output-root-dir DIR] [--cmssw-src-dir DIR] [--sample-cfg FILE] [--proxy-path FILE] <input_list.txt> <job_dir>

Arguments:
  input_list.txt  Text file with one input ROOT path per line
  job_dir         Destination folder for the generated .sh and .job

Options:
  --output-root-dir DIR  Directory where output ROOT files will be written
  --cmssw-src-dir DIR    CMSSW src directory to embed in the job runner
  --sample-cfg FILE      sample_cfg.py to use for config generation
  --proxy-path FILE      X509 proxy path to embed in the Condor submit file
  --quiet               Suppress non-error output

USAGE
}

OUTPUT_ROOT_DIR_ARG=""
CMSSW_SRC_DIR_ARG=""
SAMPLE_CFG_ARG=""
PROXY_PATH_ARG=""
QUIET=0
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet)
      QUIET=1
      shift
      ;;
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
    --cmssw-src-dir)
      if [ $# -lt 2 ]; then
        echo "ERROR: --cmssw-src-dir requires a value" >&2
        exit 1
      fi
      CMSSW_SRC_DIR_ARG="$2"
      shift 2
      ;;
    --cmssw-src-dir=*)
      CMSSW_SRC_DIR_ARG="${1#*=}"
      shift
      ;;
    --sample-cfg)
      if [ $# -lt 2 ]; then
        echo "ERROR: --sample-cfg requires a value" >&2
        exit 1
      fi
      SAMPLE_CFG_ARG="$2"
      shift 2
      ;;
    --sample-cfg=*)
      SAMPLE_CFG_ARG="${1#*=}"
      shift
      ;;
    --proxy-path)
      if [ $# -lt 2 ]; then
        echo "ERROR: --proxy-path requires a value" >&2
        exit 1
      fi
      PROXY_PATH_ARG="$2"
      shift 2
      ;;
    --proxy-path=*)
      PROXY_PATH_ARG="${1#*=}"
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

# Resolve CMSSW src dir if provided.
CMSSW_SRC_DIR_ABS=""
if [ -n "$CMSSW_SRC_DIR_ARG" ]; then
  if [[ "$CMSSW_SRC_DIR_ARG" = /* ]]; then
    CMSSW_SRC_DIR_ABS="$CMSSW_SRC_DIR_ARG"
  else
    CMSSW_SRC_DIR_ABS="$REPO_ROOT/$CMSSW_SRC_DIR_ARG"
  fi
fi

# Resolve sample cfg if provided.
SAMPLE_CFG_ABS=""
if [ -n "$SAMPLE_CFG_ARG" ]; then
  if [[ "$SAMPLE_CFG_ARG" = /* ]]; then
    SAMPLE_CFG_ABS="$SAMPLE_CFG_ARG"
  else
    SAMPLE_CFG_ABS="$REPO_ROOT/$SAMPLE_CFG_ARG"
  fi
  if [ ! -f "$SAMPLE_CFG_ABS" ]; then
    echo "ERROR: sample cfg not found: $SAMPLE_CFG_ABS" >&2
    exit 1
  fi
fi

# Resolve proxy path if provided.
PROXY_PATH_ABS=""
if [ -n "$PROXY_PATH_ARG" ]; then
  if [[ "$PROXY_PATH_ARG" = /* ]]; then
    PROXY_PATH_ABS="$PROXY_PATH_ARG"
  else
    PROXY_PATH_ABS="$REPO_ROOT/$PROXY_PATH_ARG"
  fi
  if [ ! -f "$PROXY_PATH_ABS" ]; then
    echo "WARNING: proxy path not found at generation time: $PROXY_PATH_ABS" >&2
  fi
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

# Copy the batch list into the job directory for reproducibility and to ensure
# the runner uses a stable, job-local input_list.txt.
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
# The copied input list lives alongside this script (job-local input_list.txt).
INPUT_LIST="$JOB_INPUT_LIST"
# Write output ROOT files into the configured output directory.
OUTPUT_ROOT_DIR="$OUTPUT_ROOT_DIR_ABS"
# Store generated configs under a timestamped subfolder within the job folder.
CFG_BASE_DIR="$JOB_DIR_ABS/cms_cfgs"
# Allow override for CMSSW source; otherwise use the repo-adjacent default.
CMSSW_SRC_DIR="\${CMSSW_SRC_DIR:-${CMSSW_SRC_DIR_ABS:-$REPO_ROOT/../CMSSW_15_1_0_patch4/src}}"
SAMPLE_CFG="${SAMPLE_CFG_ABS}"

# Ensure output folders exist before running.
mkdir -p "\$OUTPUT_ROOT_DIR" "\$CFG_BASE_DIR"

# Run the batch helper: generate cfgs + run cmsRun per file.
if [ -n "\$SAMPLE_CFG" ]; then
  "\$REPO_ROOT/condor/run_batch_cmsrun.sh" --sample-cfg "\$SAMPLE_CFG" "\$INPUT_LIST" "\$OUTPUT_ROOT_DIR" "\$CMSSW_SRC_DIR" "\$CFG_BASE_DIR"
else
  "\$REPO_ROOT/condor/run_batch_cmsrun.sh" "\$INPUT_LIST" "\$OUTPUT_ROOT_DIR" "\$CMSSW_SRC_DIR" "\$CFG_BASE_DIR"
fi
EOF

# Ensure the runner script is executable for Condor.
chmod +x "$RUN_SH"

# Write the Condor job description file.
PROXY_JOB_LINES=""
if [ -n "$PROXY_PATH_ABS" ]; then
  PROXY_JOB_LINES=$(cat <<EOF
use_x509userproxy = true
x509userproxy = $PROXY_PATH_ABS
EOF
)
fi

cat <<EOF > "$JOB_FILE"
universe              = vanilla
executable            = ${SUBMIT_JOB_DIR}/my_exec.sh
initialdir            = ${SUBMIT_JOB_DIR}
getenv                = true

$PROXY_JOB_LINES

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
if [ "$QUIET" -eq 0 ]; then
  echo "Wrote runner: $RUN_SH"
  echo "Wrote job   : $JOB_FILE"
  echo "Input list  : $JOB_INPUT_LIST"
  echo "Output ROOT : $OUTPUT_ROOT_DIR_ABS"
fi
