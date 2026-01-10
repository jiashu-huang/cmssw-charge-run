#!/bin/bash
set -euo pipefail

################################################################################
#
# run_cmsdriver.sh
# Generate a cmsDriver.py config for running CMSSW_15_1_0_patch4 with CMSSW_15_CHARGE branch.
# Jiashu Huang (2025-01-10)
#
################################################################################

# Define usage message
usage() {
  cat <<'USAGE'
Usage: run_cmsdriver.sh <cmssw_src_dir> <test_file_path> [config_py] [output_root] [nevents]

Arguments:
  cmssw_src_dir   Path to the CMSSW src directory (default: ../../CMSSW_15_1_0_patch4/src/)
  test_file_path  Input file path or xrootd URL (default: ../input_file_path.txt)
  config_py       Config output path (default: ./manual_cfg.py)
  output_root     Output ROOT file (default is created by name of input file)
  nevents         Optional number of events (default: 100)
USAGE
}

# Obtain the location where this .sh file is at.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Parse command-line arguments.
# 1. CMSSW src directory
CMSSW_SRC_DIR=${1:-"$SCRIPT_DIR/../../CMSSW_15_1_0_patch4/src/"} # Default: ../../CMSSW_15_1_0_patch4/src/
if [ ! -d "$CMSSW_SRC_DIR" ]; then
  echo "ERROR: CMSSW src directory not found: $CMSSW_SRC_DIR" >&2
  exit 1
fi
CMSSW_BASE_DIR=$(cd "$CMSSW_SRC_DIR/.." && pwd)           # Use the CMSSW base (one level above src) to keep outputs alongside the release.

# 2. Test file path
TEST_FILE_PATH=${2:-"$SCRIPT_DIR/../input_file_path.txt"} # Default: ../input_file_path.txt
if [ -f "$TEST_FILE_PATH" ]; then
  # If it's a file, read the first line as the test file path.
  TEST_FILE_PATH=$(head -n 1 "$TEST_FILE_PATH" | tr -d '\r')
fi

if [ -z "$TEST_FILE_PATH" ]; then
  echo "ERROR: Test file path is empty." >&2
  exit 1
fi

# 3. Config output path
CONFIG_PY=${3:-"$SCRIPT_DIR/manual_cfg.py"}                          # Default config is placed next to this script for discoverability and versioning.

# 4. Create default name of output file based on input file's name
if [ -n "${4:-}" ]; then
  OUTPUT_ROOT=$4
else
  INPUT_BASENAME=$(basename "$TEST_FILE_PATH")
  INPUT_NAME="${INPUT_BASENAME%.*}"  # Strip extension
  OUTPUT_ROOT="$CMSSW_BASE_DIR/output/${INPUT_NAME}_CMSSW_15_CHARGE_NanoAOD.root"
fi

# 5. Optional number of events to process.
# If number is -1, cmsDriver.py will process all events in the input file.
NEVENTS=${5:-100} # A small event count keeps test runs fast and predictable.

# Print out the parsed arguments for verification.
printf 'CMSSW src dir: %s\n' "$CMSSW_SRC_DIR"
printf 'Test file path: %s\n' "$TEST_FILE_PATH"
printf 'Config output: %s\n' "$CONFIG_PY"
printf 'Output ROOT: %s\n' "$OUTPUT_ROOT"
printf 'Number of events: %s\n' "$NEVENTS"
echo ""

################################################################################

# Set up the CMS environment for cmsDriver.py.
set +u
source /cvmfs/cms.cern.ch/cmsset_default.sh
set -u
cd "$CMSSW_SRC_DIR"
eval "$(scramv1 runtime -sh)"

# Determine the input file URI based on the provided test file path.
case "$TEST_FILE_PATH" in
  root://*|file:*)
    # Case: Already a fully qualified input URI.
    FILEIN="$TEST_FILE_PATH"
    ;;
  /store/*)
    # Case: Remote file on EOS; route via the global redirector.
    FILEIN="root://cms-xrd-global.cern.ch//${TEST_FILE_PATH#/}"
    ;;
  *)
    # Case: Local file path.
    if [ ! -f "$TEST_FILE_PATH" ]; then
      echo "ERROR: Local input file not found: $TEST_FILE_PATH" >&2
      exit 1
    fi
    FILEIN="file:$TEST_FILE_PATH"
    ;;
esac

# Ensure output directory exists before generating config.
mkdir -p "$(dirname "$OUTPUT_ROOT")"
if [ ! -w "$(dirname "$OUTPUT_ROOT")" ]; then
  echo "ERROR: Output directory is not writable: $(dirname "$OUTPUT_ROOT")" >&2
  exit 1
fi

# Read cmsDriver.py settings from ./cmsdriver_variables.sh
source "$SCRIPT_DIR/cmsdriver_variables.sh"
if [ -z "${GLOBALTAG:-}" ] || [ -z "${ERA:-}" ] || [ -z "${EVENTCONTENT:-}" ] || \
   [ -z "${DATATIER:-}" ] || [ -z "${STEP:-}" ] || [ -z "${MC_FLAG:-}" ]; then
  echo "ERROR: Missing required variables in cmsdriver_variables.sh" >&2
  exit 1
fi

# Print out cmsdriver_variables.sh settings for verification.
printf 'Using cmsDriver.py settings:\n'
printf '  GLOBALTAG: %s\n' "$GLOBALTAG"
printf '  ERA: %s\n' "$ERA"
printf '  EVENTCONTENT: %s\n' "$EVENTCONTENT"
printf '  DATATIER: %s\n' "$DATATIER"
printf '  STEP: %s\n' "$STEP"
printf '  MC_FLAG: %s\n' "$MC_FLAG"

# Generate the cmsDriver.py config for NanoAODSIM production.
printf 'Generating config: %s\n' "$CONFIG_PY"
printf 'Input: %s\n' "$FILEIN"
printf 'Output: %s\n' "$OUTPUT_ROOT"
printf 'Events: %s\n' "$NEVENTS"

echo -e "Begin running cmsDriver now...\n\n"

cmsDriver.py nano_step \
  --filein "$FILEIN" \
  --fileout "file:$OUTPUT_ROOT" \
  $MC_FLAG \
  --eventcontent "$EVENTCONTENT" \
  --datatier "$DATATIER" \
  --conditions "$GLOBALTAG" \
  --step "$STEP" \
  --era "$ERA" \
  --python_filename "$CONFIG_PY" \
  --no_exec \
  -n "$NEVENTS"

echo -e "\nConfig generation complete: $CONFIG_PY"
echo -e "You can now run the config with:\n>> cmsRun $CONFIG_PY"
