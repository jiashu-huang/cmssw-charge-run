# Condor

This folder contains the files needed to run condor jobs. 

* `generate_config.py`: To run, do

  ```bash
  python3 ./condor/generate_config.py <input_root_path> <cfg_dir> [root_dir]
  ```

  - `<cfg_dir>` is where the generated config will be written.
  - `[root_dir]` is optional; it controls where the output `.root` file is written
    inside the config. Default is `../CMSSW_15_1_0_patch4/output` (relative to the
    repo root).

  Example: 

  ```bash
  python3 ./condor/generate_config.py /store/mc/Run3Summer22MiniAODv4/TTtoLplusNu2Q-2Jets_TuneCP5_13p6TeV_amcatnloFXFX-pythia8/MINIAODSIM/130X_mcRun3_2022_realistic_v5-v1/70000/2b148b77-ce18-4dde-998a-c5ba8c7ab2d5.root ./condor/ ./condor/
  ```
