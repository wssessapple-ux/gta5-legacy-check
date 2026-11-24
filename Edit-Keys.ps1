#requires -Version 5.1
<#
  trainerv.ini 按键编辑器（Simple Trainer 1.9 系列）
  - 图形界面：选一行 → 按你想绑的键 → 保存（自动备份 .bak，只改等号右边的数字）
  - 命令行：-List 出表，-Check 列共用键，-Set "MenuKey=F3" 直接改
  - 手柄项（Controller*）存的是手柄码，单独手填，不跟键盘混
#>
param(
    [string]$Ini,
    [string]$GameDir,
    [switch]$List,
    [switch]$Check,
    [string[]]$Set,
    [switch]$NoGui
)

$ErrorActionPreference = 'Stop'

# ---------- 键码表 ----------
function New-VkMap {
    $m = @{}
    for ($i = 65; $i -le 90; $i++) { $m[$i] = [string][char]$i }
    for ($i = 48; $i -le 57; $i++) { $m[$i] = [string]$i }
    for ($i = 96; $i -le 105; $i++) { $m[$i] = 'Numpad' + ($i - 96) }
    for ($i = 112; $i -le 135; $i++) { $m[$i] = 'F' + ($i - 111) }
    $spec = @{}
    $spec[1] = 'Escape'; $spec[8] = 'Backspace'; $spec[9] = 'Tab'; $spec[13] = 'Enter'
    $spec[16] = 'Shift'; $spec[17] = 'Ctrl'; $spec[18] = 'Alt'
    $spec[19] = 'Pause'; $spec[20] = 'CapsLock'; $spec[27] = 'Esc'; $spec[32] = 'Space'
    $spec[33] = 'PageUp'; $spec[34] = 'PageDown'; $spec[35] = 'End'; $spec[36] = 'Home'
    $spec[37] = 'Left'; $spec[38] = 'Up'; $spec[39] = 'Right'; $spec[40] = 'Down'
    $spec[44] = 'PrintScreen'; $spec[45] = 'Insert'; $spec[46] = 'Delete'
    $spec[91] = 'LWin'; $spec[92] = 'RWin'; $spec[93] = 'Apps'
    $spec[106] = 'Numpad*'; $spec[107] = 'Numpad+'; $spec[109] = 'Numpad-'
    $spec[110] = 'Numpad.'; $spec[111] = 'Numpad/'
    $spec[144] = 'NumLock'; $spec[145] = 'ScrollLock'
    $spec[160] = 'LShift'; $spec[161] = 'RShift'; $spec[162] = 'LCtrl'; $spec[163] = 'RCtrl'
    $spec[164] = 'LAlt'; $spec[165] = 'RAlt'
    $spec[186] = ';'; $spec[187] = '='; $spec[188] = ','; $spec[189] = '-'
    $spec[190] = '.'; $spec[191] = '/'; $spec[192] = 'Grave'
    $spec[219] = '['; $spec[220] = '\'; $spec[221] = ']'; $spec[222] = "'"
    foreach ($k in @($spec.Keys)) { $m[[int]$k] = $spec[[int]$k] }
    $m
}

# 手柄码（Simple Trainer 的虚拟映射）
$PAD = @{
    201 = 'A'; 202 = 'B'; 203 = 'X'; 204 = 'Y'
    205 = 'LB'; 206 = 'RB'; 207 = 'LT'; 208 = 'RT'
    187 = '十字下'; 188 = '十字上'; 189 = '十字左'; 190 = '十字右'
    209 = 'Start'; 210 = 'Back'; 211 = 'LS'; 212 = 'RS'
}
$MOUSE = @{ 240 = '鼠标左'; 241 = '鼠标右'; 242 = '鼠标中'; 243 = '鼠标侧1'; 244 = '鼠标侧2' }

$VK = New-VkMap
$VKRev = @{}
foreach ($k in @($VK.Keys)) {
    $n = $VK[[int]$k]
    if ($n -and -not $VKRev.ContainsKey($n)) { $VKRev[$n] = [int]$k }
}
$alias = @{ 'ESC'='Escape'; 'DEL'='Delete'; 'INS'='Insert'; 'PGUP'='PageUp'; 'PGDN'='PageDown'
            'LCTRL'='LCtrl'; 'RCTRL'='RCtrl'; 'LSHIFT'='LShift'; 'RSHIFT'='RShift'
            'LALT'='LAlt'; 'RALT'='RAlt'; 'APPS'='Apps'; 'MENU'='Apps' }

function Get-KeyName($code) {
    $c = [int]$code
    if ($MOUSE.ContainsKey($c)) { return $MOUSE[$c] }
    if ($VK.ContainsKey($c)) { return $VK[$c] }
    "VK$c"
}
function Get-PadName($code) {
    $c = [int]$code
    if ($PAD.ContainsKey($c)) { "手柄 " + $PAD[$c] } else { "手柄码 $c" }
}
function Test-PadEntry($name) { $name -match '^Controller' }

function ConvertTo-KeyCode([string]$s) {
    $s = $s.Trim()
    if ($s -match '^VK(\d+)$') { return [int]$Matches[1] }
    if ($s -match '^\d+$') { return [int]$s }
    $up = $s.ToUpperInvariant()
    if ($alias.ContainsKey($up)) { $up = $alias[$up].ToUpperInvariant() }
    foreach ($k in @($MOUSE.Keys)) { if ($MOUSE[$k] -eq $s) { return [int]$k } }
    foreach ($n in @($VKRev.Keys)) { if ($n.ToUpperInvariant() -eq $up) { return $VKRev[$n] } }
    if ($up -match '^F(\d{1,2})$') { $i = 111 + [int]$Matches[1]; if ($i -ge 112 -and $i -le 135) { return $i } }
    if ($up -match '^NUMPAD(\d)$') { return 96 + [int]$Matches[1] }
    throw "认不出这个键名：$s（可以直接写 VK 数字，比如 114）"
}

# ---------- 定位 ini ----------
if (-not $Ini) {
    if ($GameDir) {
        $Ini = Join-Path $GameDir 'trainerv.ini'
    } else {
        $cand = @((Join-Path $PSScriptRoot 'trainerv.ini'), 'E:\vip\GTAV\trainerv.ini') |
                Where-Object { Test-Path -LiteralPath $_ }
        $Ini = $cand | Select-Object -First 1
    }
}
if (-not $Ini -or -not (Test-Path -LiteralPath $Ini)) {
    Write-Host "找不到 trainerv.ini，用 -Ini 指定路径。" -ForegroundColor Red
    exit 2
}
$Ini = (Resolve-Path -LiteralPath $Ini).Path

function Read-Bindings([string]$path) {
    $lines = @(Get-Content -LiteralPath $path)
    $inKB = $false
    $items = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\s*\[(.+)\]\s*') { $inKB = ($Matches[1] -eq 'KeyBindings'); continue }
        if (-not $inKB) { continue }
        if ($line -match '^\s*(\w+)\s*=\s*(\d+)\s*(.*)$') {
            [void]$items.Add([pscustomobject]@{
                Name = $Matches[1]; Code = [int]$Matches[2]; Line = $i; Tail = $Matches[3]
            })
        }
    }
    @{ Lines = $lines; Items = @($items) }
}

function Save-Bindings([string]$path, $data, [hashtable]$patch) {
    $lines = @(Get-Content -LiteralPath $path)
    $changed = 0
    foreach ($name in @($patch.Keys)) {
        $hit = $data.Items | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if (-not $hit) { throw "ini 里没有这一项：$name" }
        $old = $lines[$hit.Line]
        if ($old -notmatch '^(\s*\w+\s*=\s*)(\d+)(.*)$') { throw "这行格式不认识：$old" }
        $new = '{0}{1}{2}' -f $Matches[1], $patch[$name], $Matches[3]
        if ($new -ne $old) { $lines[$hit.Line] = $new; $changed++ }
    }
    if ($changed -eq 0) { return 0 }
    Copy-Item -LiteralPath $path -Destination ($path + '.bak') -Force
    # trainerv.ini 是 ANSI(GBK) 编码，用系统默认编码写回，注释才不变乱码
    $enc = [Text.Encoding]::Default
    $raw = [IO.File]::ReadAllText($path)
    $nl = if ($raw -match "`r`n") { "`r`n" } else { "`n" }
    [IO.File]::WriteAllText($path, (($lines -join $nl) + $nl), $enc)
    $changed
}

# ---------- 共用键判定 ----------
# 修饰键（LAlt/LCtrl/LShift…）本来就是组合键前缀，被多组共用是设计，不算冲突
$MODKEY = @('LAlt','RAlt','LCtrl','RCtrl','LShift','RShift','Shift','Ctrl','Alt','LWin','RWin')
function Get-Conflicts($items, $pending) {
    $map = @{}
    foreach ($it in $items) {
        if (Test-PadEntry $it.Name) { continue }
        $code = if ($pending -and $pending.ContainsKey($it.Name)) { $pending[$it.Name] } else { $it.Code }
        if ($MODKEY -contains (Get-KeyName $code)) { continue }
        if (-not $map.ContainsKey($code)) { $map[$code] = @() }
        $map[$code] += $it.Name
    }
    $map.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | ForEach-Object {
        [pscustomobject]@{
            键       = Get-KeyName ([int]$_.Key)
            VK       = [int]$_.Key
            项       = ($_.Value -join '、')
            涉及改动 = [bool]($pending -and @($_.Value | Where-Object { $pending.ContainsKey($_) }).Count -gt 0)
        }
    }
}

function Show-Table($data, [switch]$withCheck) {
    $data.Items | ForEach-Object {
        [pscustomobject]@{
            名称 = $_.Name
            键   = if (Test-PadEntry $_.Name) { Get-PadName $_.Code } else { Get-KeyName $_.Code }
            VK   = $_.Code
            注释 = ($_.Tail -replace '//', '' -replace '\s+', '').Trim()
        }
    } | Format-Table -AutoSize
    if ($withCheck) {
        $c = @(Get-Conflicts $data.Items $null)
        if ($c.Count -eq 0) {
            Write-Host "没有非修饰键共用。" -ForegroundColor Green
        } else {
            Write-Host ("{0} 组共用键（原版设计，按菜单上下文生效）：" -f $c.Count) -ForegroundColor Yellow
            $c | Format-Table -AutoSize
        }
    }
}

# ---------- 命令行 ----------
$data = Read-Bindings $Ini
if ($Set.Count -gt 0) {
    # 允许一条参数里塞多项（逗号或分号分隔），方便 pwsh -File 调用
    $pairs = @()
    foreach ($chunk in $Set) {
        foreach ($p in ($chunk -split '[,;]')) { if ($p.Trim()) { $pairs += $p.Trim() } }
    }
    $patch = @{}
    foreach ($s in $pairs) {
        if ($s -notmatch '^(.+?)=(.+)$') { throw "格式应为 名称=键，例如 MenuKey=F3" }
        $name = $Matches[1].Trim(); $key = $Matches[2].Trim()
        $item = $data.Items | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if (-not $item) { throw "ini 里没有这一项：$name" }
        if (Test-PadEntry $name) { $code = [int]$key } else { $code = ConvertTo-KeyCode $key }
        $patch[$name] = $code
        $oldName = if (Test-PadEntry $name) { Get-PadName $item.Code } else { Get-KeyName $item.Code }
        Write-Host ("{0}: {1} → {2}（VK {3}）" -f $name, $oldName, $key, $code)
    }
    $n = Save-Bindings $Ini $data $patch
    Write-Host ("写回 {0} 项，备份 trainerv.ini.bak" -f $n) -ForegroundColor Green
    exit 0
}
if ($List -or $Check -or $NoGui) {
    Write-Host ("{0}    共 {1} 项" -f $Ini, $data.Items.Count)
    Show-Table $data -withCheck:$Check
    exit 0
}

# ---------- GUI ----------
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, Microsoft.VisualBasic

$form = New-Object Windows.Forms.Form
$form.Text = "trainerv.ini 按键编辑器"
$form.ClientSize = New-Object Drawing.Size(760, 604)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9)

$lbl = New-Object Windows.Forms.Label
$lbl.Text = "双击一行 → 按你想绑的键。手柄项（Controller）要手填手柄码。保存前自动备份 .bak。"
$lbl.Location = New-Object Drawing.Point(12, 10)
$lbl.AutoSize = $true
$form.Controls.Add($lbl)

$grid = New-Object Windows.Forms.DataGridView
$grid.Location = New-Object Drawing.Point(12, 36)
$grid.Size = New-Object Drawing.Size(736, 472)
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.ReadOnly = $true
$grid.RowHeadersVisible = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.MultiSelect = $false
$grid.CellBorderStyle = 'SingleHorizontal'
$form.Controls.Add($grid)

$col1 = New-Object Windows.Forms.DataGridViewTextBoxColumn
$col1.HeaderText = '名称'; $col1.Width = 200
$col2 = New-Object Windows.Forms.DataGridViewTextBoxColumn
$col2.HeaderText = '当前键'; $col2.Width = 140
$col3 = New-Object Windows.Forms.DataGridViewTextBoxColumn
$col3.HeaderText = 'VK'; $col3.Width = 70
$col4 = New-Object Windows.Forms.DataGridViewTextBoxColumn
$col4.HeaderText = '注释'; $col4.AutoSizeMode = 'Fill'
[void]$grid.Columns.AddRange([Windows.Forms.DataGridViewColumn[]]@($col1, $col2, $col3, $col4))

$btnKey = New-Object Windows.Forms.Button
$btnKey.Text = "改键"; $btnKey.Location = New-Object Drawing.Point(12, 518); $btnKey.Size = New-Object Drawing.Size(100, 30)
$form.Controls.Add($btnKey)
$btnSave = New-Object Windows.Forms.Button
$btnSave.Text = "保存"; $btnSave.Location = New-Object Drawing.Point(124, 518); $btnSave.Size = New-Object Drawing.Size(90, 30)
$form.Controls.Add($btnSave)
$btnReload = New-Object Windows.Forms.Button
$btnReload.Text = "重新读"; $btnReload.Location = New-Object Drawing.Point(226, 518); $btnReload.Size = New-Object Drawing.Size(90, 30)
$form.Controls.Add($btnReload)
$btnConf = New-Object Windows.Forms.Button
$btnConf.Text = "查共用键"; $btnConf.Location = New-Object Drawing.Point(328, 518); $btnConf.Size = New-Object Drawing.Size(100, 30)
$form.Controls.Add($btnConf)

$status = New-Object Windows.Forms.Label
$status.Location = New-Object Drawing.Point(12, 554)
$status.Size = New-Object Drawing.Size(736, 40)
$form.Controls.Add($status)

$script:pending = @{}

function Refresh-Grid {
    $grid.Rows.Clear()
    foreach ($it in $data.Items) {
        $isPad = Test-PadEntry $it.Name
        $code = if ($script:pending.ContainsKey($it.Name)) { $script:pending[$it.Name] } else { $it.Code }
        $show = if ($isPad) { Get-PadName $code } else { Get-KeyName $code }
        $note = ($it.Tail -replace '//', '' -replace '\s+', '').Trim()
        $row = $grid.Rows.Add($it.Name, $show, $code, $note)
        if ($isPad) { $grid.Rows[$row].DefaultCellStyle.ForeColor = [Drawing.Color]::DimGray }
        if ($script:pending.ContainsKey($it.Name)) {
            $grid.Rows[$row].Cells[1].Style.BackColor = [Drawing.Color]::LightGoldenrodYellow
        }
    }
    # 只标「改动带来的冲突」，原版那堆共用键不刷红
    $conf = @(Get-Conflicts $data.Items $script:pending | Where-Object { $_.涉及改动 })
    foreach ($c in $conf) {
        foreach ($r in $grid.Rows) {
            if ([int]$r.Cells[2].Value -eq $c.VK -and -not (Test-PadEntry $r.Cells[0].Value)) {
                $r.Cells[1].Style.BackColor = [Drawing.Color]::MistyRose
                $r.Cells[2].Style.BackColor = [Drawing.Color]::MistyRose
            }
        }
    }
    $n = @($script:pending.Keys).Count
    $status.Text = if ($n -gt 0) { "$Ini    未保存：$n 项" } else { $Ini }
}

function Capture-Key([string]$name) {
    $cap = New-Object Windows.Forms.Form
    $cap.Text = "绑定：$name"
    $cap.ClientSize = New-Object Drawing.Size(420, 170)
    $cap.StartPosition = 'CenterParent'
    $cap.FormBorderStyle = 'FixedDialog'
    $cap.MaximizeBox = $false
    $cap.MinimizeBox = $false
    $cap.KeyPreview = $true
    $hint = New-Object Windows.Forms.Label
    $hint.Text = "请按键…（Esc 取消）"
    $hint.Font = New-Object Drawing.Font('Microsoft YaHei UI', 14)
    $hint.TextAlign = 'MiddleCenter'
    $hint.Dock = 'Fill'
    $cap.Controls.Add($hint)
    $script:captured = $null
    $cap.Add_KeyDown({
        param($s, $e)
        if ($e.KeyCode -eq [Windows.Forms.Keys]::Escape) { $s.Close(); return }
        $script:captured = [int]$e.KeyCode
        $s.Close()
    })
    $cap.Add_MouseDown({
        param($s, $e)
        $script:captured = switch ($e.Button) { 'Left' { 240 } 'Right' { 241 } 'Middle' { 242 } default { 243 } }
        $s.Close()
    })
    [void]$cap.ShowDialog($form)
    $script:captured
}

function Capture-Pad([string]$name, [int]$current) {
    $map = "201=A   202=B   203=X   204=Y   206=RB   205=LB`n187=十字下  188=十字上  189=十字左  190=十字右"
    $v = [Microsoft.VisualBasic.Interaction]::InputBox("输入手柄码（当前 $current）：`n`n$map", "手柄键：$name", "$current")
    if ($v -eq '' -or $null -eq $v) { return $null }
    if ($v -notmatch '^\d+$') { [Windows.Forms.MessageBox]::Show('只能填数字手柄码。'); return $null }
    [int]$v
}

$btnKey.Add_Click({
    if ($grid.SelectedRows.Count -eq 0) { [Windows.Forms.MessageBox]::Show('先选一行。'); return }
    $row = $grid.SelectedRows[0]
    $name = [string]$row.Cells[0].Value
    if (Test-PadEntry $name) {
        $vk = Capture-Pad $name ([int]$row.Cells[2].Value)
        if ($null -eq $vk) { return }
        $script:pending[$name] = [int]$vk
    } else {
        $vk = Capture-Key $name
        if ($null -eq $vk -or [int]$vk -eq 0) { return }
        $script:pending[$name] = [int]$vk
    }
    Refresh-Grid
})

$grid.Add_CellDoubleClick({ param($s, $e) if ($e.RowIndex -ge 0) { $btnKey.PerformClick() } })

$btnConf.Add_Click({
    $c = @(Get-Conflicts $data.Items $script:pending)
    if ($c.Count -eq 0) { [Windows.Forms.MessageBox]::Show('没有非修饰键共用。'); return }
    $txt = ($c | ForEach-Object { "{0}（VK {1}）：{2}" -f $_.键, $_.VK, $_.项 }) -join "`n"
    [Windows.Forms.MessageBox]::Show(("{0} 组共用键：`n`n{1}" -f $c.Count, $txt), '共用键')
})

$btnSave.Add_Click({
    if (@($script:pending.Keys).Count -eq 0) { [Windows.Forms.MessageBox]::Show('没有改动。'); return }
    $conf = @(Get-Conflicts $data.Items $script:pending | Where-Object { $_.涉及改动 })
    if ($conf.Count -gt 0) {
        $txt = ($conf | ForEach-Object { "{0}（VK {1}）：{2}" -f $_.键, $_.VK, $_.项 }) -join "`n"
        $r = [Windows.Forms.MessageBox]::Show(("你改的键跟这些功能撞了：`n`n{0}`n`n仍然保存？" -f $txt), '键位冲突', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
    }
    try {
        $n = Save-Bindings $Ini $data $script:pending
        $script:pending = @{}
        $data = Read-Bindings $Ini
        Refresh-Grid
        [Windows.Forms.MessageBox]::Show(("已保存 {0} 项，原文件备份为 trainerv.ini.bak" -f $n))
    } catch {
        [Windows.Forms.MessageBox]::Show(('保存失败：' + $_.Exception.Message), '错误', 'OK', 'Error')
    }
})

$btnReload.Add_Click({
    $script:pending = @{}
    $data = Read-Bindings $Ini
    Refresh-Grid
})

Refresh-Grid
[void]$form.ShowDialog()
