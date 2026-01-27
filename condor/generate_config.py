#!/usr/bin/env python3
import argparse
import os
import re
import sys


def normalize_input_path(path: str) -> str:
    if path.startswith(("root://", "xrdfs://", "file:")):
        return path
    if path.startswith("/store/"):
        return f"root://cms-xrd-global.cern.ch//{path.lstrip('/')}"
    if os.path.exists(path):
        return f"file:{os.path.abspath(path)}"
    return path


def build_output_root(input_path: str, output_dir: str) -> str:
    base = os.path.basename(input_path)
    if base.endswith(".root"):
        base = base[:-5]
    return os.path.join(output_dir, f"{base}_CMSSW_15_CHARGE_NanoAOD.root")


def replace_cfg(sample_text: str, filein: str, fileout: str) -> str:
    filein_pat = re.compile(r"(fileNames\s*=\s*cms\.untracked\.vstring\()\s*'[^']*'(\)\s*,?)")
    fileout_pat = re.compile(r"(fileName\s*=\s*cms\.untracked\.string\()\s*'[^']*'(\)\s*,?)")

    new_text, n1 = filein_pat.subn(lambda m: f"{m.group(1)}'{filein}'{m.group(2)}", sample_text, count=1)
    new_text, n2 = fileout_pat.subn(lambda m: f"{m.group(1)}'file:{fileout}'{m.group(2)}", new_text, count=1)

    if n1 != 1 or n2 != 1:
        raise RuntimeError("Failed to replace fileNames/fileName in sample config.")
    return new_text


def main() -> int:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_sample = os.path.join(script_dir, "sample_cfg.py")

    ap = argparse.ArgumentParser(description="Generate a per-file CMSSW config from sample_cfg.py.")
    ap.add_argument("input_path", help="Input file path (/store/... or root://... or local file)")
    ap.add_argument("cfg_dir", help="Directory where the output cfg will be written")
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    default_output_dir = os.path.join(repo_root, "..", "CMSSW_15_1_0_patch4", "output")
    ap.add_argument("root_dir", nargs="?", default=default_output_dir,
                    help="Directory for output ROOT files (default: ../CMSSW_15_1_0_patch4/output)")
    ap.add_argument("--sample", default=default_sample, help="Path to sample_cfg.py")
    args = ap.parse_args()

    if not os.path.isfile(args.sample):
        print(f"ERROR: sample config not found: {args.sample}", file=sys.stderr)
        return 1

    cfg_dir = os.path.abspath(args.cfg_dir)
    os.makedirs(cfg_dir, exist_ok=True)
    output_dir = os.path.abspath(args.root_dir)
    os.makedirs(output_dir, exist_ok=True)

    filein = normalize_input_path(args.input_path)
    fileout = build_output_root(args.input_path, output_dir)

    base = os.path.basename(args.input_path)
    if base.endswith(".root"):
        base = base[:-5]

    output_cfg = os.path.join(cfg_dir, f"{base}_cfg.py")

    with open(args.sample, "r", encoding="utf-8") as f:
        sample_text = f.read()

    new_text = replace_cfg(sample_text, filein, fileout)

    with open(output_cfg, "w", encoding="utf-8") as f:
        f.write(new_text)

    print(f"\nWrote config: {output_cfg}")
    print(f"\n>> Input : {filein}")
    print(f"\n>> Output: file:{fileout}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
