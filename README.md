# dsh-lean4-prover

[English](#english) · 中文

一个 [DSH NEXT](https://github.com/)（DeepSeek Harness）技能/插件：用 **Lean 4 + Mathlib** 自动完成数学与金融模型的**形式化证明**，并以「本地大模型大量试错 + 强模型攻坚 + CPU 多核并行验证」的方式闭环。

- 双层模型路由：本地 [Ollama](https://ollama.com)（零成本批量试错）↔ DeepSeek 等 API（核心命题攻坚）
- 多核并行候选验证：同一定理生成多个候选证明，先过者胜
- **严格验收闸门**：编译零错误 · 无 `sorry/admit/axiom/unsafe` · `#print axioms` 仅允许白名单公理
- 自带已验收示例：APT 套利定价最小二乘核心引理、多剂量给药药物蓄积（闭式解 / 稳态有界收敛 / 非负）

---

## 它能做什么

用自然语言给出命题（数学定理、线性代数/概率引理、金融模型），由智能体走标准证明循环：

```
拆层建模 → 声明先行 → 生成证明 → 三合一验收 → 失败修复 → 并行择优 → 全量构建交付
```

产出一份可编译、无占位符、公理受控的 `.lean` 证明。

## 前置环境（插件不含 Lean 工具链）

| 依赖 | 说明 |
|---|---|
| Python 3.10+ | 运行 `assets/lean4-prover/tools/*.py` |
| elan + Lean 4 + Mathlib | 首次在项目目录运行 `scripts/setup_env.ps1`（数 GB，约 20–60 分钟） |
| Ollama + 模型（可选） | 本地出证明草稿，如 `ollama pull qwen3.6:35b-a3b` |
| `DEEPSEEK_API_KEY`（可选） | 仅 API 攻坚模式需要 |

> 安装脚本从 GitHub 拉取，直连不通的网络请先配置系统代理/`HTTPS_PROXY`。

## 安装（两种方式）

### 方式 A：作为 DSH NEXT 插件（推荐，设置页可见可开关）

1. 完全退出 DSH NEXT（安装要原子替换 profile 目录，运行中会报 EBUSY；失败自动回滚）。
2. 克隆本仓库后，在仓库根目录运行：

   ```powershell
   powershell -ExecutionPolicy Bypass -File install-plugin.ps1
   ```

   脚本调用官方 `dsh-plugin-doctor` 完成审计、装入 desktop profile、验证启动。
3. 重新打开 DSH NEXT，在「设置 → 插件」可见 `dsh-lean4-prover`，对话中即可使用。

也可手动：

```powershell
$doctor = "$env:USERPROFILE\.dsh\profiles\desktop\node_modules\.bin\dsh-plugin-doctor.CMD"
& $doctor install . --profile desktop --no-isolate
```

### 方式 B：仅作为文件系统技能（最轻量）

把 `assets/lean4-prover` 目录复制为 `%USERPROFILE%\.dsh\skills\lean4-prover`（确保其中是大写 `SKILL.md`），重启 DSH NEXT。此形态不在插件页显示卡片，但对话中同样可用。

## 使用

在 DSH NEXT 对话中直接说，例如：

> 用 Lean 4 证明：固定剂量多次给药，浓度递推 c(n+1)=q·c(n)+D 收敛到稳态且恒非负。

或手动调用工具（在一个已拉取 Mathlib 缓存的 Lean 项目内）：

```powershell
python tools/lean_build.py check "Nat.add_zero"                      # 声明先行：查类型
python tools/llm_router.py local sketch "命题描述"                    # 本地模型出大纲
python tools/llm_router.py local lean_code sketch.txt                # 大纲翻成 Lean
python tools/lean_verify.py MyApt/Apt.lean --thm MyApt.APT.apt_core  # 三合一验收
python tools/lean_parallel.py ./candidates --workers 18              # 多核并行择优
```

环境变量：`LEAN_PROJECT`（默认 `C:\work\lean\my_apt`）、`OLLAMA_MODEL`、`OLLAMA_URL`、`LEAN_API_URL`、`LEAN_API_MODEL`、`DEEPSEEK_API_KEY`。

## 目录结构

```
dsh-lean4-prover/
├── package.json            # cordis/npm 插件清单
├── cordis.patch.yml        # 启动时插入插件行
├── lib/index.js            # ctx.skills.registerProvider 注册 bundled skill
├── install-plugin.ps1      # Windows 一键安装（官方 doctor）
└── assets/lean4-prover/
    ├── SKILL.md            # 技能定义（触发条件/工作流/验收标准）
    ├── tools/              # lean_build / lean_verify / lean_parallel / llm_router
    ├── scripts/setup_env.ps1
    └── examples/           # Apt.lean、Pharmacokinetics.lean（已通过验收）
```

## 白名单公理

`propext`、`Quot.sound`、`Classical.choice`、`funext`、`Lean.ofReduceBool`（可用 `lean_verify.py --allow` 追加）。

## 许可

[MIT](LICENSE)

---

<a name="english"></a>
## English

A DSH NEXT skill/plugin for **formal proofs in Lean 4 + Mathlib** (math and quantitative-finance models), with a dual-layer LLM router (local Ollama for cheap trial-and-error, API model for hard goals), multi-core parallel candidate verification, and a strict acceptance gate (compiles, no `sorry`/`admit`/`axiom`/`unsafe`, axioms whitelisted). Ships two verified examples: an APT least-squares core lemma and a repeated-dose pharmacokinetics model (closed form / bounded convergence / non-negativity).

**Setup:** Python 3.10+, elan/Lean 4/Mathlib via `assets/lean4-prover/scripts/setup_env.ps1`, optionally Ollama and a DeepSeek API key.

**Install (DSH NEXT plugin):** fully quit DSH NEXT, then `powershell -ExecutionPolicy Bypass -File install-plugin.ps1` (uses the official `dsh-plugin-doctor`; auto-rollback on failure). Reopen DSH NEXT; the plugin appears under Settings → Plugins.

**Skill-only:** copy `assets/lean4-prover` to `~/.dsh/skills/lean4-prover` (note uppercase `SKILL.md`) and restart.

Licensed under the [MIT License](LICENSE).
