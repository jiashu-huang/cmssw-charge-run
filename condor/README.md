# Condor

This folder contains helper scripts for CMSSW batch and Condor runs.

## Dataset-first workflow (recommended)

Batch a DAS dataset into per-batch input lists (with CMSSW + proxy precheck).

To run:

```bash
./condor/batch_dataset.sh --dataset "<DATASET>" --batch-size 10 --out-base batch-data-paths
```

Example:

```bash
./condor/batch_dataset.sh \
  --dataset "/TTtoLplusNu2Q-2Jets_TuneCP5_13p6TeV_amcatnloFXFX-pythia8/Run3Summer22MiniAODv4-130X_mcRun3_2022_realistic_v5-v1/MINIAODSIM" \
  --batch-size 10 \
  --out-base batch-data-paths
```

Optional args recorded into `metadata.txt` for downstream job creation:

- `--output-root-base DIR` (default: `--out-base`)
- `--job-root DIR` (default: `./condor-jobs`)
- `--cmssw-src-dir DIR` (default: `$CMSSW_SRC_DIR` if set)
- `--sample-cfg FILE` (optional)
- `--proxy-path FILE` (optional; auto-filled by `batch_dataset.sh` when a proxy exists)

This creates:

- `batch-data-paths/<dataset>/batches/batch_000.txt`, `batch_001.txt`, ...
- `batch-data-paths/<dataset>/files_all.txt`
- `batch-data-paths/<dataset>/dataset.txt`

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
./condor/run_batch_cmsrun.sh [--dry-run|--manual] [--sample-cfg FILE] <input_list.txt> <output_root_dir> [cmssw_src_dir] [cfg_base_dir]
```

- Generates per-file configs and runs `cmsRun` for each input.
- With `--dry-run` / `--manual`, configs are generated but `cmsRun` is skipped.

## make_condor_batch.sh

To run:

```bash
./condor/make_condor_batch.sh [--quiet] [--output-root-dir DIR] [--cmssw-src-dir DIR] [--sample-cfg FILE] [--proxy-path FILE] <input_list.txt> <job_dir>
```

- Creates `<job_dir>/my_exec.sh` and `<job_dir>/my_job.job`, and copies the input list.
- The submit file is written assuming you will submit from the repo root.
- Output ROOT files default to `<job_dir>`. Use `--output-root-dir` to override;
  relative paths are treated as repo-root relative.

Submit from the repo root with:

```bash
condor_submit <job_dir>/my_job.job
```

## make_condor_batches.sh

Create per-batch Condor jobs from a batch directory.

```bash
./condor/make_condor_batches.sh <batch_dir|dataset_dir> [--job-root DIR] [--output-root-base DIR] [--cmssw-src-dir DIR] [--sample-cfg FILE] [--proxy-path FILE]
```

If `--job-root` / `--output-root-base` are omitted, values are read from
`<dataset_dir>/metadata.txt` (written by `batch_dataset.sh`). Otherwise defaults
apply. The default `job_root` is `<dataset_dir>/condor-jobs`.
If `proxy_path` exists in `metadata.txt`, it is used to set `x509userproxy`
in each generated submit file.

`<batch_dir>` may be either the dataset directory or the `batches/` subfolder.

This creates job folders directly under:

- `<job_root>/batch_000/`
- `<job_root>/batch_001/`

Each batch list is copied into the job folder as `input_list.txt`, and the runner uses that
job-local file.

and writes outputs to:

- `<output_root_base>/<dataset>/batch_000/` (when `output_root_base` is outside the dataset dir)
- `<output_root_base>/batch_000/` (when `output_root_base` is inside the dataset dir)

## submit_all_jobs.sh

Submit all job files under a job root.

```bash
./condor/submit_all_jobs.sh <job_root>
```

Use `--dry-run` to print without submitting:

```bash
./condor/submit_all_jobs.sh --dry-run <job_root>
```

Note: `submit_all_jobs.sh` runs `proxy_precheck.sh` to ensure a valid proxy exists.
