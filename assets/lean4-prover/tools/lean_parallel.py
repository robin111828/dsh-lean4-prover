#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""并行候选验证：利用多核 CPU 同时验证多个候选 .lean 文件（同一定理不同证明尝试）。

本机 20 核，默认 workers = 核数 - 2。Lean 单文件验证读 olean 缓存，并行无锁竞争。

用法:
  python lean_parallel.py <候选文件或目录> [--workers N]
"""
import argparse
import concurrent.futures
import glob
import json
import os
import subprocess
import sys

# Windows 中文控制台默认 GBK，强制标准输出/错误用 UTF-8，避免打印含 Unicode 的 JSON 崩溃
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except Exception:
        pass

PROJECT = os.environ.get("LEAN_PROJECT", r"C:\work\lean\my_apt")
DEFAULT_WORKERS = max(1, (os.cpu_count() or 4) - 2)

def check_one(path):
    try:
        p = subprocess.run(["lake", "env", "lean", path], cwd=PROJECT,
                           capture_output=True, text=True, encoding="utf-8",
                           errors="replace", timeout=1800)
        return {"file": path, "ok": p.returncode == 0, "tail": (p.stdout + p.stderr)[-1200:]}
    except Exception as e:
        return {"file": path, "ok": False, "tail": f"EXC: {e}"}

def main():
    ap = argparse.ArgumentParser(description="并行候选验证")
    ap.add_argument("target", help="候选 .lean 文件或目录")
    ap.add_argument("--workers", type=int, default=DEFAULT_WORKERS)
    args = ap.parse_args()

    if os.path.isdir(args.target):
        files = sorted(glob.glob(os.path.join(args.target, "*.lean")))
    else:
        files = [args.target]

    if not files:
        print(json.dumps({"error": "no lean files found"}, ensure_ascii=False))
        sys.exit(1)

    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(args.workers, len(files))) as ex:
        for r in ex.map(check_one, files):
            results.append(r)

    ok_files = [r["file"] for r in results if r["ok"]]
    print(json.dumps({"total": len(results), "passed": ok_files, "results": results},
                     ensure_ascii=False, indent=2))
    sys.exit(0 if ok_files else 1)

if __name__ == "__main__":
    main()
