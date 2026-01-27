# Condor

This folder contains helper scripts for CMSSW batch and Condor runs.

## generate_config.py

To run:

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

## run_batch_cmsrun.sh

To run:

```bash
./condor/run_batch_cmsrun.sh [--dry-run|--manual] <input_list.txt> <output_root_dir> [cmssw_src_dir] [cfg_base_dir]
```

- Generates per-file configs and runs `cmsRun` for each input.
- With `--dry-run` / `--manual`, configs are generated but `cmsRun` is skipped.

## make_condor_batch.sh

To run:

```bash
./condor/make_condor_batch.sh [--output-root-dir DIR] <input_list.txt> <job_dir>
```

- Creates `<job_dir>/my_exec.sh` and `<job_dir>/my_job.job`, and copies the input list.
- The submit file is written assuming you will submit from the repo root.
- Output ROOT files default to `<job_dir>`. Use `--output-root-dir` to override;
  relative paths are treated as repo-root relative.

Submit from the repo root with:

```bash
condor_submit <job_dir>/my_job.job
```
