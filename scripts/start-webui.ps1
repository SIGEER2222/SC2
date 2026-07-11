<#
.SYNOPSIS
  启动 SC2 合作指挥官-起义狂潮 WebUI。
.DESCRIPTION
  进入 web-launcher 目录，安装依赖（如缺失），启动 express 服务器。
  服务器监听 http://127.0.0.1:17761/。
.PARAMETER NoInstall
  跳过 npm install 检查。
.EXAMPLE
  .\start-webui.ps1
  .\start-webui.ps1 -NoInstall
#>
param(
    [switch]$NoInstall
)

$ErrorActionPreference = "Stop"

# === 路径解析 ===
$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
$WebLauncherDir = Join-Path $ScriptRoot "..\合作指挥官-起义狂潮\web-launcher"

if (-not (Test-Path -LiteralPath $WebLauncherDir)) {
    Write-Host "ERROR: web-launcher 目录不存在: $WebLauncherDir" -ForegroundColor Red
    exit 1
}

Write-Host "=== SC2 WebUI Launcher ==="
Write-Host "web-launcher 目录: $WebLauncherDir"

# === 检查依赖 ===
if (-not $NoInstall) {
    $nodeModules = Join-Path $WebLauncherDir "node_modules"
    if (-not (Test-Path -LiteralPath $nodeModules)) {
        Write-Host "node_modules 不存在，执行 npm install..." -ForegroundColor Yellow
        Push-Location $WebLauncherDir
        try {
            npm install
        } finally {
            Pop-Location
        }
        Write-Host "npm install 完成" -ForegroundColor Green
    }
}

# === 启动服务器 ===
Write-Host "启动 WebUI 服务器..." -ForegroundColor Cyan
Write-Host "访问地址: http://127.0.0.1:17761/" -ForegroundColor Cyan
Write-Host "按 Ctrl+C 停止服务器" -ForegroundColor DarkGray
Write-Host ""

Push-Location $WebLauncherDir
try {
    node server.mjs
} finally {
    Pop-Location
}
