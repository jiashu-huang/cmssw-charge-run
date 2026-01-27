# Running `CMSSW_15_CHARGE`

This folder contains files that allow you to run `CMSSW_15_CHARGE` both manually and automatically via Condor.
You should have a version of CMSSW installed (e.g. `CMSSW_15_1_0_patch4`) with `CMSSW_15_CHARGE` added to it
via `git cms-init` and `git cms-merge-topic`. 
I have another repo for setting up CMSSW with `CMSSW_15_CHARGE`.

## Run Manually on One File

0. Paste the path of the file in [./input_file_path.txt](./input_file_path.txt)

1. Set up environment:

```bash
source manual_setup.sh
```

2. Obtain CMS driver on all events.
The usage is `run_cmsdriver.sh <cmssw_src_dir> <test_file_path> [config_py] [output_root] [nevents]`, where 

* the default CMSSW src is located at `../CMSSW_15_1_0_patch4/src`.
* the default test file path is `./input_file_path.txt`
* the default config file is [./manual/manual_cfg.py](./manual/manual_cfg.py)
* the default output root is located under `../CMSSW_15_1_0_patch4/output/`, by the name `${INPUT_NAME}_CMSSW_15_CHARGE_NanoAOD.root`.
* Use -1 for `nevents` if you wish to process all events.

```bash
source ./manual/run_cmsdriver.sh "" "" "" "" -1
```

3. Execute run

```bash
cmsRun /home/jhuan166/Vcb/cmssw-charge-run/manual/manual_cfg.py
```

## Run Automatically in Batches via Condor

0. 
