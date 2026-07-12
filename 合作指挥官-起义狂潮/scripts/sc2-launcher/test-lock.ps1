<#
.SYNOPSIS
  SC2 测试锁机制（Test Lock）
  确保同一时间只有一个测试会话能启动游戏，避免多个 AI/脚本互相覆盖 SC2 进程。
.DESCRIPTION
  锁文件: out/.test.lock (JSON)
  超时: 3 分钟（180 秒），超时自动释放
  机制:
    - Acquire-TestLock: 获取锁，失败则抛出异常退出
    - Release-TestLock: 释放锁（仅持有者可释放）
    - Get-TestLockStatus: 查看锁状态
    - TestLock监听: 持有者进程退出时自动失效

  集成方式（在 launch 脚本中）:
    . (Join-Path $LauncherScriptsRoot "test-lock.ps1")
    $lockCtx = Acquire-TestLock -TestType "reborn_commander" -MapName $MapName -Commander $Commander
    try {
        # ... 测试逻辑 ...
    } finally {
        Release-TestLock -LockContext $lockCtx
    }
#>

# 支持被 launch 脚本 dot-source 加载（$ProjRoot 已定义）或独立运行
if (-not (Get-Variable -Name ProjRoot -Scope Script -ErrorAction SilentlyContinue)) {
    # 独立运行时：从当前文件路径推导项目根目录
    $script:ProjRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    if (-not $script:ProjRoot -or -not (Test-Path $script:ProjRoot)) {
        # 兜底：使用用户目录
        $script:ProjRoot = "E:\Code\MyMod\SC2\合作指挥官-起义狂潮"
    }
} else {
    $script:ProjRoot = $ProjRoot
}

$script:TestLockFile = Join-Path $script:ProjRoot "out\.test.lock"
$script:TestLockTimeoutSeconds = 180  # 3 分钟

if (-not (Test-Path (Split-Path $script:TestLockFile -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $script:TestLockFile -Parent) -Force | Out-Null
}

<#
  读取锁文件内容，返回 $null 表示无锁
#>
function Read-TestLock {
    if (-not (Test-Path -LiteralPath $script:TestLockFile)) {
        return $null
    }
    try {
        $content = [System.IO.File]::ReadAllText($script:TestLockFile)
        return $content | ConvertFrom-Json
    } catch {
        # 锁文件损坏，视为无锁
        return $null
    }
}

<#
  检查 PID 是否还在运行
#>
function Test-PidAlive {
    param([int]$ProcessId)
    if ($ProcessId -le 0) { return $false }
    $proc = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    return ($null -ne $proc)
}

<#
  判断锁是否已过期
#>
function Test-LockExpired {
    param($Lock)
    if ($null -eq $Lock) { return $true }
    if (-not $Lock.expires_at) { return $true }
    try {
        $expires = [DateTime]::Parse($Lock.expires_at)
        return ([DateTime]::UtcNow -gt $expires)
    } catch {
        return $true
    }
}

<#
  查看锁状态（不获取也不释放）
#>
function Get-TestLockStatus {
    $lock = Read-TestLock
    if ($null -eq $lock) {
        return @{ acquired = $false; reason = "no_lock_file" }
    }
    $expired = Test-LockExpired -Lock $lock
    $pidAlive = Test-PidAlive -ProcessId $lock.holder_pid
    return @{
        acquired = $true
        expired = $expired
        pid_alive = $pidAlive
        holder_pid = $lock.holder_pid
        holder_script = $lock.holder_script
        test_type = $lock.test_type
        map_name = $lock.map_name
        commander = $lock.commander
        acquired_at = $lock.acquired_at
        expires_at = $lock.expires_at
        session_id = $lock.session_id
        usable = ($expired -or -not $pidAlive)
    }
}

<#
  获取测试锁
  成功返回 LockContext（用于释放），失败抛出异常
#>
function Acquire-TestLock {
    param(
        [Parameter(Mandatory=$true)][string]$TestType,
        [Parameter(Mandatory=$true)][string]$MapName,
        [string]$Commander = "",
        [string]$HolderScript = $null
    )

    if (-not $HolderScript) {
        $HolderScript = Split-Path $PSCommandPath -Leaf
        if (-not $HolderScript) { $HolderScript = "unknown" }
    }

    $now = [DateTime]::UtcNow
    $expires = $now.AddSeconds($script:TestLockTimeoutSeconds)
    $sessionId = "${TestType}-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([System.Guid]::NewGuid().ToString().Substring(0,8))"

    # 检查现有锁
    $existing = Read-TestLock
    if ($null -ne $existing) {
        $expired = Test-LockExpired -Lock $existing
        $pidAlive = Test-PidAlive -ProcessId $existing.holder_pid

        if (-not $expired -and $pidAlive) {
            # 锁仍然有效，拒绝
            $remaining = ""
            try {
                $exp = [DateTime]::Parse($existing.expires_at)
                $secs = [int]($exp - [DateTime]::UtcNow).TotalSeconds
                if ($secs -gt 0) { $remaining = " (剩余 ${secs}s)" }
            } catch {}
            $msg = "测试锁被占用: PID=$($existing.holder_pid) 脚本=$($existing.holder_script)" +
                   " 测试=$($existing.test_type) 地图=$($existing.map_name)" +
                   " 指挥官=$($existing.commander) 过期=$($existing.expires_at)$remaining"
            throw $msg
        }
        # 锁已过期或持有者进程已退出，可抢占
        if ($expired) {
            Write-Host "[TestLock] 旧锁已过期，自动抢占" -ForegroundColor Yellow
        } else {
            Write-Host "[TestLock] 旧锁持有者进程已退出，自动抢占" -ForegroundColor Yellow
        }
    }

    # 写入新锁（原子操作：先写临时文件再移动）
    $lockObj = [ordered]@{
        holder_pid = $PID
        holder_script = $HolderScript
        test_type = $TestType
        map_name = $MapName
        commander = $Commander
        acquired_at = $now.ToString("o")
        expires_at = $expires.ToString("o")
        session_id = $sessionId
    }
    $lockJson = $lockObj | ConvertTo-Json -Compress

    $tmpFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tmpFile, $lockJson, [System.Text.UTF8Encoding]::new($false))
        # MoveTo 会原子性替换
        [System.IO.File]::Move($tmpFile, $script:TestLockFile)
    } catch {
        if (Test-Path $tmpFile) { Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue }
        throw "写入测试锁失败: $_"
    }

    Write-Host "[TestLock] 已获取锁: session=$sessionId PID=$PID 过期=$($expires.ToString('o'))" -ForegroundColor Green
    return @{
        session_id = $sessionId
        holder_pid = $PID
        lock_file = $script:TestLockFile
    }
}

<#
  释放测试锁
  仅当当前会话是持有者时才释放
#>
function Release-TestLock {
    param($LockContext)

    if ($null -eq $LockContext) { return }

    $existing = Read-TestLock
    if ($null -eq $existing) {
        Write-Host "[TestLock] 锁文件不存在，无需释放" -ForegroundColor DarkGray
        return
    }

    # 仅当 session_id 匹配时才释放（防止释放别人的锁）
    if ($existing.session_id -ne $LockContext.session_id) {
        Write-Host "[TestLock] 锁已被其他会话持有，不释放" -ForegroundColor Yellow
        return
    }

    try {
        Remove-Item -LiteralPath $script:TestLockFile -Force -ErrorAction Stop
        Write-Host "[TestLock] 锁已释放: session=$($LockContext.session_id)" -ForegroundColor Green
    } catch {
        Write-Host "[TestLock] 释放锁失败: $_" -ForegroundColor Yellow
    }
}

<#
  续期锁（在长时间测试中调用）
#>
function Renew-TestLock {
    param($LockContext, [int]$AdditionalSeconds = $script:TestLockTimeoutSeconds)

    if ($null -eq $LockContext) { return $false }

    $existing = Read-TestLock
    if ($null -eq $existing) { return $false }
    if ($existing.session_id -ne $LockContext.session_id) { return $false }

    $newExpires = [DateTime]::UtcNow.AddSeconds($AdditionalSeconds)
    $existing.expires_at = $newExpires.ToString("o")
    $lockJson = $existing | ConvertTo-Json -Compress

    $tmpFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tmpFile, $lockJson, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::Move($tmpFile, $script:TestLockFile)
        Write-Host "[TestLock] 锁已续期至 $($newExpires.ToString('o'))" -ForegroundColor DarkGray
        return $true
    } catch {
        if (Test-Path $tmpFile) { Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue }
        return $false
    }
}
