# Lean 4 + Mathlib 一键环境安装（Windows 原生，针对本机硬件定制）
# 用法: powershell -ExecutionPolicy Bypass -File setup_env.ps1
# 目标: 版本锁定 + 预编译缓存 + VS Code 交互式证明

$ErrorActionPreference = "Stop"
$projRoot = "C:\work\lean"
$projName = "my_apt"

Write-Host "[1/6] 安装 VS Code / Git (winget)..."
winget install --id Microsoft.VisualStudioCode -e --silent --accept-package-agreements --accept-source-agreements
winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements

Write-Host "[2/6] 安装 elan (Lean 版本管理器)..."
if (-not (Get-Command lean -ErrorAction SilentlyContinue)) {
    curl.exe -L https://elan.lean-lang.org/elan-init.ps1 -o "$env:TEMP\elan-init.ps1"
    powershell -ExecutionPolicy Bypass -File "$env:TEMP\elan-init.ps1"
    Remove-Item "$env:TEMP\elan-init.ps1"
    # 重新加载 PATH
    $env:Path = "$env:USERPROFILE\.elan\bin;" + $env:Path
}

Write-Host "[3/6] 验证工具链..."
lean --version
lake --version

Write-Host "[4/6] 安装 VS Code Lean 4 扩展..."
code --install-extension leanprover.lean4

Write-Host "[5/6] 创建版本锁定项目 (mathlib4 官方 toolchain)..."
New-Item -ItemType Directory -Force -Path $projRoot | Out-Null
Set-Location $projRoot
if (-not (Test-Path $projName)) {
    lake +leanprover-community/mathlib4:lean-toolchain new $projName math
}

Write-Host "[6/6] 拉取 Mathlib 预编译缓存并构建..."
Set-Location "$projRoot\$projName"
lake exe cache get
lake build

Write-Host "=============================================="
Write-Host "完成。项目位于: $projRoot\$projName"
Write-Host "本地推理检查: nvidia-smi / ollama ps (qwen3.6:35b-a3b 双卡并行)"
Write-Host "下一步: python lean4-prover/tools/lean_verify.py MyApt/Basic.lean --thm <定理名>"
Write-Host "=============================================="
