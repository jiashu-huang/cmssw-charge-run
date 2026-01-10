#!/bin/bash

################################################################################
# 
# manual_setup.sh
# Set up CMSSW_15_1_0_patch4 and prepare to run a job manually.
# Jiashu Huang (2025-01-10)
# 
################################################################################

# Check if ../CMSSW_15_1_0_patch4 exists; if not, exit with error.
if [ ! -d "../CMSSW_15_1_0_patch4" ]; then
  echo "ERROR: CMSSW_15_1_0_patch4 directory not found in ../" >&2
  exit 1 
fi

# Initiate VOMS proxy
voms-proxy-init --voms cms --valid 168:00

# Set up CMSSW environment
source /cvmfs/cms.cern.ch/cmsset_default.sh

# Echo setup message and tell the user what to do next.
echo -e "Manual setup complete. Next steps:"
echo -e "\t1. Paste file path in input_file_path.txt (one file only)."
echo -e "\t2. Run ./run_cmsdriver.sh to generate cmsDriver.py config."
echo -e "\t   To pass input arguments optionally:"
echo -e '\t   >> source ./manual/run_cmsdriver.sh "" "" "" "" -1'
