# dsh-lean4-prover 一键安装脚本（Windows / DSH NEXT desktop profile）
# 用法：先完全退出 DSH NEXT，再运行
#   powershell -ExecutionPolicy Bypass -File install-plugin.ps1

$ErrorActionPreference = "Stop"

# 插件目录即本脚本所在目录，避免写死机器路径
$pluginDir = $PSScriptRoot
$profileDir = Join-Path $env:USERPROFILE ".dsh\profiles\desktop"
$doctor    = Join-Path $profileDir "node_modules\.bin\dsh-plugin-doctor.CMD"
$dupSkill  = Join-Path $env:USERPROFILE ".dsh\skills\lean4-prover"

Write-Host "[1/4] 检查 DSH NEXT 是否已退出..." -ForegroundColor Cyan
$procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*DSH NEXT*" }
if ($procs) {
    Write-Host "  DSH NEXT 仍在运行（PID: $($procs.Id -join ', ')）。" -ForegroundColor Red
    Write-Host "  请先在任务栏右键完全退出 DSH NEXT，再重新运行本脚本。" -ForegroundColor Yellow
    exit 1
}
Write-Host "  已退出，继续。" -ForegroundColor Green

if (-not (Test-Path $doctor)) {
    Write-Host "未找到 dsh-plugin-doctor：$doctor" -ForegroundColor Red
    Write-Host "请确认 DSH NEXT 已正确安装（desktop profile 存在）。" -ForegroundColor Yellow
    exit 1
}

Write-Host "[2/4] 静态校验插件包..." -ForegroundColor Cyan
& $doctor check $pluginDir --no-isolate
if ($LASTEXITCODE -ne 0) { Write-Host "doctor check 未通过，中止。" -ForegroundColor Red; exit 1 }
Remove-Item (Join-Path $pluginDir "reports") -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "[3/4] 安装到 desktop profile（失败会自动回滚）..." -ForegroundColor Cyan
& $doctor install $pluginDir --profile desktop --no-isolate
if ($LASTEXITCODE -ne 0) { Write-Host "安装失败，已自动回滚，请把上方日志发给作者。" -ForegroundColor Red; exit 1 }
Remove-Item (Join-Path $pluginDir "reports") -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  插件安装成功。" -ForegroundColor Green

Write-Host "[4/4] 移除 ~/.dsh/skills 下的重复技能副本，避免重复注册..." -ForegroundColor Cyan
if (Test-Path $dupSkill) {
    $bak = "$dupSkill.bak-" + (Get-Date -Format "yyyyMMddHHmmss")
    Rename-Item $dupSkill $bak
    Write-Host "  已把旧副本改名为: $bak" -ForegroundColor Green
    Write-Host "  确认插件可用后可手动删除该 .bak 目录。" -ForegroundColor DarkGray
} else {
    Write-Host "  无重复副本，跳过。" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "全部完成。重新打开 DSH NEXT，在 设置 → 插件 中可看到 dsh-lean4-prover。" -ForegroundColor Green
Write-Host "技能 lean4-prover 会在对话中自动可用（让助手用 Lean 证明某命题即可触发）。" -ForegroundColor Green
