#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""三合一验收：编译 + 无 sorry/admit/axiom + 公理白名单。

用法:
  python lean_verify.py <file.lean> [--thm <定理名>] [--allow <公理>]
"""
import argparse
import json
import os
import re
import subprocess
import sys

# Windows 中文控制台默认 GBK，强制标准输出/错误用 UTF-8，避免打印含 Unicode 的 JSON 崩溃
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except Exception:
        pass

PROJECT = os.environ.get("LEAN_PROJECT", r"C:\work\lean\my_apt")
WHITELIST = {"propext", "Quot.sound", "Classical.choice", "funext", "Lean.ofReduceBool"}

def run(cmd, cwd=PROJECT, timeout=1800):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=timeout)
    return p.returncode, p.stdout or "", p.stderr or ""

def scan_forbidden(text):
    hits = []
    for pat, label in [
        (r"\bsorry\b", "sorry"),
        (r"\badmit\b", "admit"),
        (r"^\s*axiom\b", "axiom"),
        (r"\bunsafe\b", "unsafe"),
    ]:
        for m in re.finditer(pat, text, re.M):
            line = text.count("\n", 0, m.start()) + 1
            hits.append({"kind": label, "line": line})
    return hits

def main():
    ap = argparse.ArgumentParser(description="Lean 证明三合一验收")
    ap.add_argument("file", help="要验收的 .lean 文件")
    ap.add_argument("--thm", default=None, help="需做公理检查的定理名")
    ap.add_argument("--allow", default=[], action="append", help="额外允许的公理")
    args = ap.parse_args()

    with open(args.file, encoding="utf-8") as f:
        src = f.read()

    report = {"file": args.file, "compile": None, "forbidden": scan_forbidden(src), "axioms": None}

    # 1) 编译验证
    rc, out, err = run(["lake", "env", "lean", args.file])
    report["compile"] = {"ok": rc == 0, "returncode": rc, "tail": (out + err)[-3000:]}

    # 2) 公理白名单检查
    if args.thm:
        # 由被验收文件推导模块名（相对 PROJECT，去扩展名，分隔符转点），临时文件需 import 它，
        # 否则 #print axioms 找不到定理名，白名单检查会形同虚设。
        file_abs = os.path.abspath(args.file)
        try:
            rel = os.path.relpath(file_abs, PROJECT)
        except ValueError:
            rel = args.file
        module = os.path.splitext(rel)[0].replace(os.sep, "/").replace("/", ".")
        tmp = os.path.join(PROJECT, ".tmp_axioms.lean")
        # 先构建目标模块，产出 .olean 到 .lake/build/lib，临时文件才能 import 到它
        run(["lake", "build", module])
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(f'import {module}\n#print axioms {args.thm}\n')
        try:
            rc2, out2, err2 = run(["lake", "env", "lean", os.path.basename(tmp)])
            combined = out2 + err2
            allow = set(args.allow) | WHITELIST
            found = []
            unresolved = False
            if re.search(r"unknown identifier|unknown constant|error", combined, re.I):
                # 定理名找不到或编译出错，不能当作通过
                unresolved = True
            else:
                # “'定理名' depends on axioms: [Axiom.A, Axiom.B]”：公理列在方括号内、不带引号
                for line in combined.splitlines():
                    if "depends on" in line:
                        mb = re.search(r"\[(.*)\]", line)
                        names = [a.strip() for a in mb.group(1).split(",")] if mb else []
                        found = [a for a in names if a and a not in allow]
            report["axioms"] = {
                "ok": (not unresolved) and len(found) == 0,
                "unresolved": unresolved,
                "non_whitelisted": found,
                "raw": combined[-1500:],
            }
        finally:
            if os.path.exists(tmp):
                os.remove(tmp)

    ok = (bool(report["compile"]["ok"])
          and len(report["forbidden"]) == 0
          and (report["axioms"] is None or report["axioms"]["ok"]))
    report["pass"] = ok
    print(json.dumps(report, ensure_ascii=False, indent=2))
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
