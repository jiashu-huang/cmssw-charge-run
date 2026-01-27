#!/bin/bash
set -euo pipefail

# Absolute repo path captured at creation time.
REPO_ROOT="/home/jhuan166/Vcb/cmssw-charge-run"
# The copied input list lives alongside this script.
INPUT_LIST="/home/jhuan166/Vcb/cmssw-charge-run/sample-job/input_list.txt"
# Write output ROOT files into the configured output directory.
OUTPUT_ROOT_DIR="/home/jhuan166/Vcb/cmssw-charge-run/../CMSSW_15_1_0_patch4/output/"
# Store generated configs under a timestamped subfolder within the job folder.
CFG_BASE_DIR="/home/jhuan166/Vcb/cmssw-charge-run/sample-job/cms_cfgs"
# Allow override for CMSSW source; otherwise use the repo-adjacent default.
CMSSW_SRC_DIR="${CMSSW_SRC_DIR:-/home/jhuan166/Vcb/cmssw-charge-run/../CMSSW_15_1_0_patch4/src}"

# Ensure output folders exist before running.
mkdir -p "$OUTPUT_ROOT_DIR" "$CFG_BASE_DIR"

# Run the batch helper: generate cfgs + run cmsRun per file.
"$REPO_ROOT/condor/run_batch_cmsrun.sh" "$INPUT_LIST" "$OUTPUT_ROOT_DIR" "$CMSSW_SRC_DIR" "$CFG_BASE_DIR"
