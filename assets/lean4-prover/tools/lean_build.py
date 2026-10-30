#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lean 4 构建/检查工具。

子命令:
  file     <path.lean>                 验证单个 Lean 文件 (lake env lean)
  project                               编译整个项目 (lake build)
  check    <expr>                       #check 查询表达式/定理类型

用法示例:
  python lean_build.py file MyApt/Basic.lean
  python lean_build.py project
  python lean_build.py check "Nat.succ"
"""
import argparse
import json
import os
import re
import subprocess
import tempfile
import sys

# Windows 中文控制台默认 GBK，强制标准输出/错误用 UTF-8，避免打印含 Unicode 的 JSON 崩溃
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except Exception:
        pass

PROJECT = os.environ.get("LEAN_PROJECT", r"C:\work\lean\my_apt")

def run(cmd, cwd=PROJECT, timeout=1800):
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=timeout)
        return p.returncode, p.stdout or "", p.stderr or ""
    except subprocess.TimeoutExpired:
        return -1, "", "TIMEOUT_EXPIRED"

def classify(err_text):
    """将 Lean 报错分类并裁剪，返回结构化信息。"""
    err = err_text or ""
    cats = []
    for pat, name in [
        (r"unknown identifier", "unknown_identifier"),
        (r"type mismatch", "type_mismatch"),
        (r"failed to synthesize instance", "instance_failure"),
        (r"tactic failed|unsolved goals|no goals to be solved", "tactic_failure"),
        (r"invalid field notation", "field_notation"),
        (r"unexpected token|expected", "syntax_error"),
        (r"declaration uses 'sorry'", "sorry_placeholder"),
        (r"failed to prove", "proof_failed"),
    ]:
        if re.search(pat, err):
            cats.append(name)
    locs = re.findall(r"^([^:\s]+):(\d+):(\d+):", err, re.M)
    return {"categories": cats, "locations": locs[:5], "tail": err[-3000:]}

def cmd_file(path):
    rc, out, err = run(["lake", "env", "lean", path])
    ok = (rc == 0 and "error" not in err.lower())
    result = {"ok": ok, "returncode": rc, "stdout_tail": out[-2000:], "stderr": classify(err)}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if ok else 1

def cmd_project():
    rc, out, err = run(["lake", "build"])
    ok = (rc == 0)
    result = {"ok": ok, "returncode": rc, "stdout_tail": out[-3000:], "stderr_tail": err[-3000:]}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if ok else 1

def cmd_check(expr):
    tmp_path = os.path.join(PROJECT, ".tmp_check.lean")
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(f'import Mathlib\n#check {expr}\n')
    try:
        rc, out, err = run(["lake", "env", "lean", os.path.basename(tmp_path)])
        ok = (rc == 0)
        print(json.dumps({"ok": ok, "output": (out + err)[-2000:]}, ensure_ascii=False, indent=2))
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
    return 0 if ok else 1

def main():
    ap = argparse.ArgumentParser(description="Lean 4 构建/检查工具")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_file = sub.add_parser("file")
    p_file.add_argument("path")
    p_proj = sub.add_parser("project")
    p_chk = sub.add_parser("check")
    p_chk.add_argument("expr")
    args = ap.parse_args()

    if args.cmd == "file":
        sys.exit(cmd_file(args.path))
    if args.cmd == "project":
        sys.exit(cmd_project())
    if args.cmd == "check":
        sys.exit(cmd_check(args.expr))

if __name__ == "__main__":
    main()
