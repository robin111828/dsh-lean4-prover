---
name: lean4-prover
version: 1.0.0
description: Lean 4 自动形式化证明技能（APT 等金融模型），双层模型路由加并行验证
author: 罗勇
---

# lean4-prover：Lean 4 自动形式化证明技能

## 触发条件

用户要求用 Lean 做形式化证明、验证数学定理、实现金融/经济模型（如套利定价模型 APT）的形式化证明、编写或修复 .lean 证明文件等。

## 硬件画像与本技能策略（针对本机定制）

- 双 NVIDIA RTX 5060 Ti 16GB（Ollama 双卡并行推理）
- Intel Core Ultra 7 265K 20 核 / 95.4GB RAM
- Windows 11 原生 Lean 4 + Mathlib

策略三条：

1. **验证与推理分离**：Lean 类型检查是纯 CPU 工作，不吃 GPU。充分利用 20 核并行验证多个候选证明文件，先过者胜。
2. **双层模型路由**：
   - 本地层：Ollama `qwen3.6:35b-a3b`（双卡并行，主力），`qwen3.8:27b` 备选。用于证明草稿、简单引理、报错定位、低质量候选批量生成——零成本可大量试错。
   - API 层：DeepSeek 等强模型。用于核心命题攻坚、复杂错误修复。质量优先。
   - 判断规则：简单引理/常规代数步骤走本地；核心线性代数命题、渐近概率论证、反复失败的错误修复走 API。
3. **验证吞吐最大化**：一次让本地模型产出 N 个候选证明文件（同一定理不同策略），`lean_parallel.py` 并行验证；Lean 增量编译对单文件验证无锁竞争。

## 前置条件

- Windows 原生 Lean 4 + Mathlib（elan/lean/lake 在 PATH）
- 项目目录：默认 `C:\work\lean\my_apt`，可用环境变量 `LEAN_PROJECT` 覆盖
- Ollama 运行中（http://127.0.0.1:11434），模型 `qwen3.6:35b-a3b`
- API 攻坚模式需设置 `DEEPSEEK_API_KEY`（或 `OPENAI_API_KEY`）

## 标准工作流（证明循环）

1. **拆层建模**：将目标命题拆为 建模层 / 核心层（纯线性代数）/ 渐近层（概率）。先证有限维核心命题，再做渐近版。定理表述宁弱勿强——模型常把经济直觉写成不可证强命题，失败时优先放宽假设。
2. **声明先行**：确定定理 statement，先 `lean_build.py check <expr>` 验证类型正确，再开始证。
3. **生成证明**：先产非形式化 proof sketch（llm_router local sketch），再翻译为 Lean tactic（llm_router local lean_code）；简单任务全程本地，复杂核心命题用 `api`。
4. **验证**：`lean_verify.py <file> --thm <定理名>` 三合一验收（编译 + 无 sorry/admit/axiom + 公理白名单）。
5. **失败修复**：把裁剪后的分类报错喂回模型（llm_router local/api fix --extra <报错>）。同类失败最多重试 2 次，之后必须切换模型层、换证明策略或放宽假设。
6. **并行择优**：核心命题卡住时，本地模型批量生成 5-10 个候选文件，`lean_parallel.py <候选目录>` 并行验证。
7. **验收通过后**：声明最终 .lean 文件为产出物。

## 工具

| 工具 | 命令 | 用途 |
|---|---|---|
| tools/lean_build.py | `file <path>` / `project` / `check <expr>` | 验证单文件 / 全项目编译 / 查询类型 |
| tools/lean_verify.py | `verify <file> --thm <name>` | 三合一验收（编译+占位符+公理） |
| tools/lean_parallel.py | `parallel <目录或文件> --workers N` | 20 核并行候选验证 |
| tools/llm_router.py | `local\|api <sketch\|lean_code\|fix> <payload>` | 双层模型路由 + 提示词模板 |
| scripts/setup_env.ps1 | 一键安装 | 首次环境构建（版本锁定+cache get） |

## 验收标准（不可绕过）

- 定理文件编译通过，无 error
- 扫描无 `sorry` / `admit` / `axiom` / `unsafe`
- `#print axioms <定理>` 仅含白名单公理（propext、Quot.sound、Classical.choice、funext、Lean.ofReduceBool）
- 声明定理与目标命题语义一致（防止表述偏差）

## 提示词纪律

- 先产非形式化 proof sketch，再翻译成 tactic 序列
- 琐碎代数交给 `linarith` / `nlinarith` / `ring` / `aesop`，模型只写关键论证
- 报错裁剪原则：只喂分类结果 + 错误尾部 2000-3000 字符，避免 Mathlib 冗长上下文淹没关键信息

## 部署位置（dsh）

本技能目录结构即 dsh Skill 标准结构（skill.md + tools/ + scripts/）。部署时复制整个 `lean4-prover` 目录到用户技能目录（如 `D:\罗老师数字员工新版\`），按 dsh 既有技能注册方式加载。
