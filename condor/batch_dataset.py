#!/usr/bin/env python3
"""
Batch a DAS dataset into per-batch input lists.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from typing import List


def normalize_dataset(dataset: str) -> str:
    dataset = dataset.strip()
    if not dataset:
        raise ValueError("Dataset is empty.")
    if not dataset.startswith("/"):
        dataset = "/" + dataset
    return dataset.rstrip("/")


def dataset_to_dirname(dataset: str) -> str:
    dataset = dataset.strip().strip("/")
    parts = [p for p in dataset.split("/") if p]
    if not parts:
        return "dataset"
    safe_parts = []
    for part in parts:
        safe = re.sub(r"[^A-Za-z0-9._+-]", "_", part)
        safe_parts.append(safe)
    return "__".join(safe_parts)


def run_dasgoclient(dataset: str) -> List[str]:
    # NOTE: This script does not create or refresh a VOMS proxy.
    # It only calls dasgoclient; you must have a valid proxy in your environment
    # (e.g., via ./create_proxy.sh and X509_USER_PROXY).
    if shutil.which("dasgoclient") is None:
        raise RuntimeError(
            "dasgoclient not found in PATH. "
            "Run: source ./cmssw_precheck.sh (or use ./condor/batch_dataset.sh)."
        )
    cmd = ["dasgoclient", "--query", f"file dataset={dataset}", "--limit", "0"]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        err = result.stderr.strip()
        raise RuntimeError(f"dasgoclient failed (exit {result.returncode}): {err}")
    files = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    return files


def write_batches(files: List[str], batches_dir: str, batch_size: int) -> int:
    total = len(files)
    n_batches = (total + batch_size - 1) // batch_size
    width = max(3, len(str(max(0, n_batches - 1))))
    for i in range(n_batches):
        start = i * batch_size
        batch = files[start : start + batch_size]
        name = f"batch_{i:0{width}d}.txt"
        path = os.path.join(batches_dir, name)
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(batch) + "\n")
    return n_batches


def clear_existing(out_dir: str, batches_dir: str) -> None:
    for name in os.listdir(out_dir):
        if name.startswith("batch_") and name.endswith(".txt"):
            os.remove(os.path.join(out_dir, name))
        elif name in {"files_all.txt", "dataset.txt", "metadata.txt"}:
            os.remove(os.path.join(out_dir, name))
    if os.path.isdir(batches_dir):
        for name in os.listdir(batches_dir):
            if name.startswith("batch_") and name.endswith(".txt"):
                os.remove(os.path.join(batches_dir, name))


def resolve_path(path: str) -> str:
    if not path:
        return ""
    return os.path.abspath(path)


def main() -> int:
    parser = argparse.ArgumentParser(description="Batch a DAS dataset into per-batch input lists.")
    parser.add_argument("--dataset", required=True, help="Dataset path, e.g. /A/B/C")
    parser.add_argument("--batch-size", type=int, default=10, help="Files per batch (default: 10)")
    parser.add_argument(
        "--out-base",
        default="batch-data-paths",
        help="Base directory for batch lists (default: batch-data-paths)",
    )
    parser.add_argument(
        "--name",
        default="",
        help="Optional override for output folder name under out-base",
    )
    parser.add_argument(
        "--output-root-base",
        default="",
        help="Base directory for output ROOT files (dataset folder appended). "
        "Default: --out-base",
    )
    parser.add_argument(
        "--job-root",
        default="",
        help="Base directory for Condor job folders (dataset folder appended). "
        "Default: <repo_root>/condor-jobs",
    )
    parser.add_argument(
        "--cmssw-src-dir",
        default="",
        help="CMSSW src directory to record for downstream jobs.",
    )
    parser.add_argument(
        "--sample-cfg",
        default="",
        help="Optional sample_cfg.py to record for downstream jobs.",
    )
    parser.add_argument(
        "--proxy-path",
        default="",
        help="Optional X509 proxy path to record for downstream jobs.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing batch files in the target directory",
    )
    args = parser.parse_args()

    if args.batch_size <= 0:
        print("ERROR: --batch-size must be > 0", file=sys.stderr)
        return 2

    dataset = normalize_dataset(args.dataset)
    out_name = args.name.strip() or dataset_to_dirname(dataset)
    out_base_abs = resolve_path(args.out_base)
    out_dir = os.path.abspath(os.path.join(out_base_abs, out_name))

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    output_root_base = resolve_path(args.output_root_base) or out_base_abs
    job_root = resolve_path(args.job_root) or os.path.join(out_dir, "condor-jobs")
    cmssw_src_dir = resolve_path(args.cmssw_src_dir) or resolve_path(os.environ.get("CMSSW_SRC_DIR", ""))
    sample_cfg = resolve_path(args.sample_cfg)
    proxy_path = resolve_path(args.proxy_path)
    batches_dir = os.path.join(out_dir, "batches")

    if os.path.isdir(out_dir):
        existing = [
            name
            for name in os.listdir(out_dir)
            if name.startswith("batch_") and name.endswith(".txt")
            or name in {"files_all.txt", "dataset.txt", "metadata.txt"}
        ]
        if existing and not args.force:
            print(
                f"ERROR: {out_dir} already contains batch files. "
                f"Use --force to overwrite.",
                file=sys.stderr,
            )
            return 3
        if args.force:
            clear_existing(out_dir, batches_dir)
    else:
        os.makedirs(out_dir, exist_ok=True)
    os.makedirs(batches_dir, exist_ok=True)

    print(f"Querying dataset: {dataset}")
    files = run_dasgoclient(dataset)
    if not files:
        print("ERROR: No files returned by dasgoclient.", file=sys.stderr)
        return 4

    files_all = os.path.join(out_dir, "files_all.txt")
    with open(files_all, "w", encoding="utf-8") as f:
        f.write("\n".join(files) + "\n")

    dataset_txt = os.path.join(out_dir, "dataset.txt")
    with open(dataset_txt, "w", encoding="utf-8") as f:
        f.write(dataset + "\n")

    metadata_txt = os.path.join(out_dir, "metadata.txt")
    with open(metadata_txt, "w", encoding="utf-8") as f:
        f.write(f"dataset: {dataset}\n")
        f.write(f"dataset_dir: {out_dir}\n")
        f.write(f"batches_dir: {batches_dir}\n")
        f.write(f"out_base: {out_base_abs}\n")
        f.write(f"batch_size: {args.batch_size}\n")
        f.write(f"total_files: {len(files)}\n")
        f.write(f"output_root_base: {output_root_base}\n")
        f.write(f"job_root: {job_root}\n")
        if cmssw_src_dir:
            f.write(f"cmssw_src_dir: {cmssw_src_dir}\n")
        if sample_cfg:
            f.write(f"sample_cfg: {sample_cfg}\n")
        if proxy_path:
            f.write(f"proxy_path: {proxy_path}\n")
        f.write(f"created_at: {datetime.utcnow().isoformat()}Z\n")

    n_batches = write_batches(files, batches_dir, args.batch_size)

    print("Batching complete.")
    print(f"Dataset dir: {out_dir}")
    print(f"Batch lists: {batches_dir}")
    print(f"Next: ./condor/make_condor_batches.sh {out_dir}")
    print(f"Output dir   : {out_dir}")
    print(f"Batch dir    : {batches_dir}")
    print(f"Total files  : {len(files)}")
    print(f"Batch size   : {args.batch_size}")
    print(f"Num batches  : {n_batches}")
    print(f"Dataset file : {dataset_txt}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
