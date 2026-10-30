#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""模型路由：本地 Ollama（双卡并行）与 API 强模型两级路由。

用法:
  python llm_router.py local  <sketch|lean_code|fix> <提示词或文件路径> [--extra <报错>]
  python llm_router.py api    <sketch|lean_code|fix> <提示词或文件路径> [--extra <报错>]

任务类型:
  sketch    生成非形式化证明大纲
  lean_code 将大纲翻译为 Lean 4 + Mathlib 代码
  fix       根据报错修复证明（--extra 传报错文本）

环境变量:
  OLLAMA_MODEL  本地模型名（默认 qwen3.6:35b-a3b，双卡并行）
  DEEPSEEK_API_KEY / OPENAI_API_KEY  API 攻坚模式必填
  LEAN_API_URL / LEAN_API_MODEL      自定义 API 端点（默认 deepseek-chat）
"""
import argparse
import json
import os
import sys
import urllib.request

# Windows 中文控制台默认 GBK，强制标准输出/错误用 UTF-8，避免打印模型中文/Unicode 内容崩溃
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except Exception:
        pass

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
LOCAL_MODEL = os.environ.get("OLLAMA_MODEL", "qwen3.6:35b-a3b")
API_URL = os.environ.get("LEAN_API_URL", "https://api.deepseek.com/v1/chat/completions")
API_MODEL = os.environ.get("LEAN_API_MODEL", "deepseek-chat")

PROMPTS = {
    "sketch": ("你是一位数学证明规划者。给出以下命题的非形式化证明大纲，"
               "标注每一步依赖的数学定理和 Lean/Mathlib 可用引理：\n\n{p}"),
    "lean_code": ("把下面的证明大纲翻译为 Lean 4 + Mathlib 可编译的完整代码。"
                  "琐碎代数交给 linarith/nlinarith/ring/aesop，关键论证手写。"
                  "只输出 Lean 代码，不要解释：\n\n{p}"),
    "fix": ("以下是 Lean 编译报错和当前证明代码。分析错误根因，"
            "输出修正后的完整 Lean 代码（只输出代码，不要解释）：\n\n"
            "错误信息（已分类）：\n{e}\n\n当前代码：\n{p}"),
}

def read_input(text):
    if os.path.isfile(text):
        with open(text, encoding="utf-8") as f:
            return f.read()
    return text

def call_ollama(prompt):
    data = json.dumps({
        "model": LOCAL_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {"num_predict": 4096, "temperature": 0.3},
    }).encode("utf-8")
    req = urllib.request.Request(OLLAMA_URL, data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=1800) as resp:
        out = json.loads(resp.read().decode("utf-8"))
    return out.get("response", "")

def call_api(prompt):
    key = os.environ.get("DEEPSEEK_API_KEY") or os.environ.get("OPENAI_API_KEY")
    if not key:
        return "ERROR: 未设置 DEEPSEEK_API_KEY / OPENAI_API_KEY"
    data = json.dumps({
        "model": API_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3,
    }).encode("utf-8")
    req = urllib.request.Request(API_URL, data=data, headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {key}",
    })
    try:
        with urllib.request.urlopen(req, timeout=1800) as resp:
            out = json.loads(resp.read().decode("utf-8"))
        return out["choices"][0]["message"]["content"]
    except Exception as e:
        return f"ERROR: {e}"

def main():
    ap = argparse.ArgumentParser(description="双层模型路由")
    ap.add_argument("backend", choices=["local", "api"])
    ap.add_argument("task", choices=list(PROMPTS.keys()))
    ap.add_argument("payload")
    ap.add_argument("--extra", default="", help="fix 任务时传报错信息")
    args = ap.parse_args()

    content = read_input(args.payload)
    if args.task == "fix":
        prompt = PROMPTS["fix"].format(e=args.extra or "(无)", p=content)
    else:
        prompt = PROMPTS[args.task].format(p=content)

    result = call_ollama(prompt) if args.backend == "local" else call_api(prompt)
    print(result)

if __name__ == "__main__":
    main()
