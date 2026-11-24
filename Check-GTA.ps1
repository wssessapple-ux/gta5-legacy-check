#
# GTA5 老版本环境体检（MIT）
#
# 干一件事：把你游戏目录里「版本对不上、必备文件缺失」的问题一次性列清楚，
# 而不是让人对着论坛帖一个个试。
#
# 用法：
#   pwsh -File Check-GTA.ps1 -GameDir 'D:\Games\Grand Theft Auto V'
#   pwsh -File Check-GTA.ps1 -GameDir . -OutFile report.md
#
param(
    [Parameter(Mandatory = $false)] [string]$GameDir = '',
    [string]$VersionsCsv = (Join-Path $PSScriptRoot 'versions.csv'),
    [string]$OutFile = '',
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

# 没给目录时自己问，省得玩家去学命令行
if (-not $GameDir) {
    Write-Host ''
    Write-Host '  GTA5 老版本环境体检' -ForegroundColor Cyan
    Write-Host '  把游戏文件夹拖进这个窗口再回车，或者直接输入路径。' -ForegroundColor Gray
    Write-Host '  一般是含 GTA5.exe 的那个目录，例如 D:\Games\Grand Theft Auto V' -ForegroundColor Gray
    Write-Host ''
    $GameDir = (Read-Host '  游戏目录').Trim().Trim('"').Trim("'")
}
if (-not $GameDir) {
    Write-Host '没给目录，退出。' -ForegroundColor Yellow
    exit 2
}
if (-not (Test-Path -LiteralPath $GameDir)) {
    Write-Host ("目录不存在：{0}" -f $GameDir) -ForegroundColor Red
    exit 2
}
$GameDir = (Resolve-Path -LiteralPath $GameDir).Path

$checks = New-Object System.Collections.Generic.List[object]
function Add([string]$level, [string]$item, [string]$detail, [string]$fix = '') {
    $checks.Add([pscustomobject]@{ Level = $level; Item = $item; Detail = $detail; Fix = $fix })
}

function Get-FileVersion([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $vi = (Get-Item -LiteralPath $path).VersionInfo
    if ($vi.FileVersion) { return $vi.FileVersion.Trim() }
    if ($vi.ProductVersion) { return $vi.ProductVersion.Trim() }
    return $null
}

function Get-VerNum([string]$v) {
    if (-not $v) { return $null }
    $m = [regex]::Match($v, '([0-9]+(?:\.[0-9]+){1,3})')
    if (-not $m.Success) { return $null }
    return ($m.Groups[1].Value.Split('.') | ForEach-Object { [int]$_ })
}

function Compare-Ver($a, $b) {
    $len = [Math]::Max($a.Count, $b.Count)
    for ($i = 0; $i -lt $len; $i++) {
        $x = if ($i -lt $a.Count) { $a[$i] } else { 0 }
        $y = if ($i -lt $b.Count) { $b[$i] } else { 0 }
        if ($x -ne $y) { return ($x - $y) }
    }
    return 0
}

# ---- 读版本对照表 ----
$table = @()
if (Test-Path -LiteralPath $VersionsCsv) { $table = Import-Csv -LiteralPath $VersionsCsv }

# ---- 1. GTA5.exe ----
$exePath = Join-Path $GameDir 'GTA5.exe'
$exeVer = Get-FileVersion $exePath
if (-not (Test-Path -LiteralPath $exePath)) {
    Add 'FATAL' 'GTA5.exe' "目录里没有 GTA5.exe：$GameDir" '确认路径指向游戏根目录（不是 mods 或 update 子目录）'
} elseif (-not $exeVer) {
    Add 'WARN' 'GTA5.exe 版本' '文件没有版本资源，读不到版本号（常见于破解/重打包版）' '拿一份正常版 GTA5.exe 再看；或者直接看 ScriptHookV.dll 版本'
} else {
    $exeNum = Get-VerNum $exeVer
    Add 'INFO' 'GTA5.exe 版本' ($exeNum -join '.')
}

# ---- 2. ScriptHookV.dll ----
$shvPath = Join-Path $GameDir 'ScriptHookV.dll'
$shvVer = Get-FileVersion $shvPath
if (-not (Test-Path -LiteralPath $shvPath)) {
    Add 'WARN' 'ScriptHookV.dll' '不存在。没有它任何 .asi 修改器都不会加载' '去 dev-c.com 下载对应你这个游戏版本的构建（文件名按游戏版本命名）'
} else {
    $shvSize = [math]::Round((Get-Item -LiteralPath $shvPath).Length / 1MB, 2)
    $shvNum = Get-VerNum $shvVer
    Add 'INFO' 'ScriptHookV.dll' ("版本 {0} / {1} MB" -f $(if ($shvNum) { $shvNum -join '.' } else { '未知' }), $shvSize)

    # 版本是否配套
    if ($exeNum -and $shvNum) {
        $cmp = Compare-Ver $shvNum $exeNum
        if ($cmp -ne 0) {
            $e = $exeNum -join '.'
            Add 'FATAL' '版本配套' ("ScriptHookV {0} 与游戏 {1} 不匹配" -f ($shvNum -join '.'), $e) `
                ("换成与游戏版本一致的构建（本版本需要 ScriptHookV {0}）。装了不匹配的 dll，表现通常是进游戏无声无息、或一加载 asi 就崩。" -f $e)
        } else {
            Add 'OK' '版本配套' "ScriptHookV 与游戏版本一致（$($exeNum -join '.')）"
        }
    } elseif ($exeNum -and -not $shvNum) {
        Add 'WARN' '版本配套' 'ScriptHookV.dll 读不到版本号，无法比对' '重新下载官方构建，别用改过的 dll'
    }
}

# ---- 3. 版本对照表命中 ----
if ($exeNum) {
    $row = $table | Where-Object {
        $rn = Get-VerNum $_.GameVersion
        $rn -and (Compare-Ver $rn $exeNum) -eq 0
    } | Select-Object -First 1
    if ($row) {
        Add 'INFO' '版本定位' ("{0}（{1}）｜修改器兼容：{2}｜{3}" -f $row.GameVersion, $row.Era, $row.TrainerCompat, $row.Note)
    } else {
        Add 'INFO' '版本定位' ("{0} 不在参照表里，按版本号自行判断" -f ($exeNum -join '.'))
    }
}

# ---- 4. ASI 加载器 ----
$loader = Join-Path $GameDir 'dinput8.dll'
if (Test-Path -LiteralPath $loader) {
    $lv = Get-FileVersion $loader
    Add 'OK' 'ASI 加载器' ("dinput8.dll 存在" + $(if ($lv) { "（$lv）" } else { '' }))
} else {
    Add 'WARN' 'ASI 加载器' '没有 dinput8.dll，.asi 不会被加载' '装 Ultimate ASI Loader（改名 dinput8.dll 放到游戏根目录）'
}

# ---- 5. OpenIV / mods ----
$openIv = Join-Path $GameDir 'OpenIV.asi'
$modsDir = Join-Path $GameDir 'mods'
if (Test-Path -LiteralPath $modsDir) {
    if (-not (Test-Path -LiteralPath $openIv)) {
        Add 'WARN' 'mods 生效' '有 mods 目录但没有 OpenIV.asi，mods 里的东西不会被加载' '装 OpenIV 并启用 ASI Manager 的 OpenIV.asi'
    } else {
        $ov = Get-FileVersion $openIv
        Add 'OK' 'mods 生效' ("mods 目录 + OpenIV.asi" + $(if ($ov) { "（$ov）" } else { '' }) + ' 已就位')
    }
} else {
    Add 'INFO' 'mods 生效' '没有 mods 目录（用原版 rpf，或还没装过替换包）'
}

# ---- 6. OpenIV.log 里的游戏版本交叉核对 ----
$log = Join-Path $GameDir 'OpenIV.log'
if (Test-Path -LiteralPath $log) {
    $line = Select-String -LiteralPath $log -Pattern 'Game version' -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($line) {
        $logVer = [regex]::Match($line.Line, '([0-9]+(?:\.[0-9]+){1,3})').Groups[1].Value
        Add 'INFO' 'OpenIV.log' "记录的游戏版本：$logVer"
        if ($exeNum -and $logVer) {
            $ln = Get-VerNum $logVer
            if ((Compare-Ver $ln $exeNum) -ne 0) {
                Add 'WARN' '日志与文件不符' ("OpenIV.log 写的是 $logVer，但你现在的 GTA5.exe 是 $exeVer") '说明游戏被换过版本或日志是旧的，以 exe 为准'
            }
        }
    }
}

# ---- 7. 修改器 ----
$asi = Get-ChildItem -LiteralPath $GameDir -Filter '*.asi' -File -ErrorAction SilentlyContinue
$trainer = $asi | Where-Object { $_.Name -match 'Trainer|trainerv' }
if ($asi.Count -gt 0) {
    Add 'INFO' '已装的 asi' (($asi | ForEach-Object { $_.Name }) -join '、')
}
if ($trainer) {
    $tf = $trainer[0]
    $tv = Get-FileVersion $tf.FullName
    # asi 一般没有版本资源，从字节里捞它自报的版本串
    if (-not $tv) {
        $head = [Text.Encoding]::Latin1.GetString([IO.File]::ReadAllBytes($tf.FullName))
        $m = [regex]::Match($head, 'Simple Trainer for GTAV Version ([0-9][0-9.]*)')
        if ($m.Success) { $tv = $m.Groups[1].Value }
    }
    Add 'INFO' '修改器' ("{0}（{1} 字节{2}）" -f $tf.Name, $tf.Length, $(if ($tv) { "，自报版本 $tv" } else { '' }))

    # Simple Trainer 1.9 只面向 2015 年的构建；游戏版本跨度大时直接提示
    $tvn = Get-VerNum $tv
    if ($exeNum -and $tvn -and ($tvn[0] -eq 1 -and $tvn[1] -eq 9) -and $exeNum[2] -ge 505) {
        Add 'WARN' '修改器适配' ("Simple Trainer 1.9 是 2015-07 的版本，配 {0} 很可能加载不了或菜单错乱" -f ($exeNum -join '.')) '换用与当前游戏版本同期的修改器，或把游戏回退到 1.0.463 一类老构建'
    }
}

# ---- 8. ScriptHookV.log ----
$shvLog = Join-Path $GameDir 'ScriptHookV.log'
if (Test-Path -LiteralPath $shvLog) {
    $tail = Get-Content -LiteralPath $shvLog -Tail 3 -ErrorAction SilentlyContinue
    Add 'INFO' 'ScriptHookV.log' '存在，最近几行：' + ($tail -join ' / ')
}

# ---- 汇总 ----
$fatal = @($checks | Where-Object Level -eq 'FATAL')
$warn = @($checks | Where-Object Level -eq 'WARN')

if ($Json) {
    $checks | ConvertTo-Json -Depth 4
} else {
    $glyph = @{ OK = '[OK]  '; INFO = '[i]   '; WARN = '[!]   '; FATAL = '[X]   ' }
    foreach ($c in $checks) {
        Write-Host ("{0}{1}  {2}" -f $glyph[$c.Level], $c.Item, $c.Detail)
        if ($c.Fix) { Write-Host ("       → {0}" -f $c.Fix) }
    }
    Write-Host ''
    if ($fatal.Count) { Write-Host ("结论：有 {0} 个致命问题，先解决再加修改器。" -f $fatal.Count) }
    elseif ($warn.Count) { Write-Host ("结论：能跑，但有 {0} 个隐患。" -f $warn.Count) }
    else { Write-Host '结论：环境完整，版本也配套。' }
}

if ($OutFile) {
    $md = @('# GTA5 环境体检报告', '', ('目录：' + $GameDir), '')
    foreach ($c in $checks) { $md += ('- **[{0}] {1}**：{2}{3}' -f $c.Level, $c.Item, $c.Detail, $(if ($c.Fix) { " → $($c.Fix)" } else { '' })) }
    $md += ''
    $md += ('结论：致命 {0} 项，隐患 {1} 项' -f $fatal.Count, $warn.Count)
    $md | Set-Content -LiteralPath $OutFile -Encoding utf8
    Write-Host "报告已写入：$OutFile"
}

if ($fatal.Count) { exit 2 } elseif ($warn.Count) { exit 1 } else { exit 0 }
