#Requires -Version 5.1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    $rawInput = [Console]::In.ReadToEnd()
    if (-not $rawInput -and $input) { $rawInput = $input | Out-String }
    if ([string]::IsNullOrWhiteSpace($rawInput)) { exit 0 }
    $payload = $rawInput | ConvertFrom-Json
} catch { exit 0 }

# --- Claude Nordic Palette ---
$ESC      = [char]27
$RESET    = "$ESC[0m"
$BOLD     = "$ESC[1m"
$C_CLAUDE = "$ESC[38;2;204;120;92m"   # Warm Terracotta
$C_FROST  = "$ESC[38;5;117m"          # Frost Cyan
$C_SLATE  = "$ESC[38;5;67m"           # Slate
$C_MUTED  = "$ESC[38;5;244m"          # Graphite
$C_DARK   = "$ESC[38;5;238m"          # Dark gray
$C_WHITE  = "$ESC[38;5;253m"          # Off-white
$C_WARN   = "$ESC[38;5;221m"          # Warm Amber
$C_ALERT  = "$ESC[38;2;224;108;74m"   # Coral
$C_GREEN  = "$ESC[38;5;114m"          # Soft green
$C_RED    = "$ESC[38;5;167m"          # Soft red

$GLYPH_CLAUDE = [char]0x25C6  # ◆
$GLYPH_SEP    = [char]0x00B7  # ·
$GLYPH_BAR    = [char]0x2501  # ━
$GLYPH_GIT    = [char]0x2387  # ⎇
$GLYPH_CLK    = [char]0x23F1  # ⏱

$C_SEP = " ${C_MUTED}${GLYPH_SEP}${RESET} "

function Format-Number($num) {
    if ($null -eq $num -or $num -le 0) { return "0" }
    if ($num -ge 1000000) { return "$([math]::Round($num / 1000000.0, 1))M" }
    elseif ($num -ge 1000) { return "$([math]::Round($num / 1000.0, 1))k" }
    else { return "$num" }
}

function Get-Bar([double]$pct, [int]$width = 10, $activeColor = $C_CLAUDE) {
    $p = [math]::Max(0, [math]::Min(100, $pct))
    $filled = [int][math]::Round(($p / 100.0) * $width)
    if ($filled -gt $width) { $filled = $width }
    if ($filled -lt 0) { $filled = 0 }
    $empty = $width - $filled
    
    $col = if ($p -ge 85.0) { $C_ALERT } elseif ($p -ge 65.0) { $C_WARN } else { $activeColor }
    $fStr = [string]$GLYPH_BAR * $filled
    $eStr = [string]$GLYPH_BAR * $empty
    return "${col}${fStr}${C_DARK}${eStr}${RESET}"
}

# 1. Model
$modelName = "Claude"
if ($payload.model -is [string]) {
    $modelName = $payload.model
} elseif ($payload.model) {
    if ($payload.model.display_name) { $modelName = $payload.model.display_name }
    elseif ($payload.model.id) { $modelName = $payload.model.id }
}
$modelSummary = ""
if ($payload.model -is [psobject] -and $payload.model.param_summary) {
    $modelSummary = " ${C_MUTED}($($payload.model.param_summary))${RESET}"
}
$modelPart = "${C_CLAUDE}${GLYPH_CLAUDE} ${C_WHITE}${BOLD}${modelName}${RESET}${modelSummary}"

# 2. Workspace Directory
$workDir = ""
if ($payload.workspace -and $payload.workspace.current_dir) { $workDir = $payload.workspace.current_dir }
elseif ($payload.cwd) { $workDir = $payload.cwd }

$homeDir = $env:USERPROFILE
$dirDisplay = "workspace"
if ($workDir) {
    if ($homeDir -and $workDir.StartsWith($homeDir, [System.StringComparison]::OrdinalIgnoreCase)) {
        $sub = $workDir.Substring($homeDir.Length)
        $dirDisplay = if ([string]::IsNullOrWhiteSpace($sub)) { "~" } else { "~" + $sub }
    } else {
        try { $dirDisplay = Split-Path -Path $workDir -Leaf } catch { $dirDisplay = $workDir }
    }
}
$dirPart = "${C_SLATE}${dirDisplay}${RESET}"

# 3. Git Status
$gitPart = ""
if ($workDir -and (Test-Path $workDir)) {
    try {
        $isGit = git -C $workDir rev-parse --is-inside-work-tree 2>$null
        if ($isGit -match "true") {
            $branch = (git -C $workDir branch --show-current 2>$null | Out-String).Trim()
            $hash = (git -C $workDir rev-parse --short HEAD 2>$null | Out-String).Trim()
            $status = (git -C $workDir status --porcelain 2>$null | Out-String).Trim()
            $dirtyMark = if ($status) { "${C_WARN}*${RESET}" } else { "" }
            $gitPart = "${C_SLATE}${GLYPH_GIT} ${branch}${dirtyMark}${RESET}"
            if ($hash) { $gitPart += " ${C_MUTED}(${hash})${RESET}" }
        }
    } catch {}
}
if (-not $gitPart) {
    $gitPart = "${C_MUTED}(local)${RESET}"
}

# 4. Session Name
$sessionPart = ""
if ($payload.session_name) {
    $sessionPart = "${C_SLATE}[$($payload.session_name)]${RESET}"
}

# 5. Cost
$costPart = ""
if ($payload.cost -and $null -ne $payload.cost.total_cost_usd) {
    $costVal = [double]$payload.cost.total_cost_usd
    if ($costVal -gt 0) {
        $costPart = "${C_WARN}`$$([math]::Round($costVal, 3))${RESET}"
    }
}

# 6. Diffs
$diffPart = ""
if ($payload.cost -and ($null -ne $payload.cost.total_lines_added -or $null -ne $payload.cost.total_lines_removed)) {
    $add = if ($payload.cost.total_lines_added) { $payload.cost.total_lines_added } else { 0 }
    $rem = if ($payload.cost.total_lines_removed) { $payload.cost.total_lines_removed } else { 0 }
    if ($add -gt 0 -or $rem -gt 0) {
        $diffPart = "${C_GREEN}+$add${RESET}${C_MUTED}/${RESET}${C_RED}-$rem${RESET}"
    }
}

# 7. Duration / Elapsed Time
$elapsedPart = ""
if ($payload.cost -and $payload.cost.total_duration_ms) {
    $durSec = [math]::Floor([double]$payload.cost.total_duration_ms / 1000.0)
    $m = [math]::Floor($durSec / 60)
    $s = $durSec % 60
    $elapsedPart = "${C_MUTED}${GLYPH_CLK} ${m}m${s}s${RESET}"
} elseif ($payload.transcript_path -and (Test-Path $payload.transcript_path)) {
    try {
        $tFile = Get-Item $payload.transcript_path
        $diff = [DateTime]::UtcNow - $tFile.CreationTimeUtc
        $m = [math]::Floor($diff.TotalMinutes)
        $elapsedPart = "${C_MUTED}${GLYPH_CLK} ${m}m${RESET}"
    } catch {}
}

# 8. Clock
$clockPart = "${C_MUTED}$([DateTime]::Now.ToString('HH:mm'))${RESET}"

# Build Line 1
$line1Parts = @($modelPart, $dirPart, $gitPart)
if ($sessionPart) { $line1Parts += $sessionPart }
if ($costPart) { $line1Parts += $costPart }
if ($diffPart) { $line1Parts += $diffPart }
# Time removed per user request
$line1 = ($line1Parts -join $C_SEP)

# --- LINE 2: Context Window & Rate Limits ---
$line2Parts = @()

# Context Window
if ($payload.context_window) {
    $ctxUsed = 0.0
    $inTok = $null
    $maxTok = $null
    if ($payload.context_window -is [double] -or $payload.context_window -is [int]) {
        $ctxUsed = [double]$payload.context_window
    } elseif ($payload.context_window -is [psobject]) {
        if ($null -ne $payload.context_window.used_percentage) {
            $ctxUsed = [double]$payload.context_window.used_percentage
        }
        $inTok = $payload.context_window.total_input_tokens
        $maxTok = $payload.context_window.context_window_size
    }
    $bar = Get-Bar -pct $ctxUsed -width 10 -activeColor $C_CLAUDE
    $cVal = if ($ctxUsed -ge 85.0) { $C_ALERT } elseif ($ctxUsed -ge 65.0) { $C_WARN } else { $C_CLAUDE }
    
    $tokStr = ""
    if ($null -ne $inTok -and $null -ne $maxTok) {
        $tokStr = " ${C_MUTED}(In: ${C_CLAUDE}$(Format-Number $inTok)${C_MUTED} / $(Format-Number $maxTok))${RESET}"
    }
    $line2Parts += "${C_MUTED}ctx:${RESET} ${bar} ${cVal}$([math]::Round($ctxUsed, 1))%${RESET}${tokStr}"
}

# 5-Hour Rate Limit
if ($payload.rate_limits -and $payload.rate_limits.five_hour) {
    $pct = 0.0
    $resetsAt = $null
    if ($payload.rate_limits.five_hour -is [double] -or $payload.rate_limits.five_hour -is [int]) {
        $pct = [double]$payload.rate_limits.five_hour
    } elseif ($payload.rate_limits.five_hour -is [psobject]) {
        if ($null -ne $payload.rate_limits.five_hour.used_percentage) {
            $pct = [double]$payload.rate_limits.five_hour.used_percentage
        }
        $resetsAt = $payload.rate_limits.five_hour.resets_at
    }
    $bar = Get-Bar -pct $pct -width 8 -activeColor $C_FROST
    $cVal = if ($pct -ge 85.0) { $C_ALERT } elseif ($pct -ge 65.0) { $C_WARN } else { $C_FROST }
    $resetStr = ""
    if ($resetsAt) {
        $localTime = [DateTimeOffset]::FromUnixTimeSeconds([int64]$resetsAt).ToLocalTime()
        $resetStr = " ${C_MUTED}($($localTime.ToString('HH:mm')))${RESET}"
    }
    $line2Parts += "${C_MUTED}5h:${RESET} ${bar} ${cVal}$([math]::Round($pct, 1))%${RESET}${resetStr}"
}

# 7-Day Rate Limit
if ($payload.rate_limits -and $payload.rate_limits.seven_day) {
    $pct = 0.0
    $resetsAt = $null
    if ($payload.rate_limits.seven_day -is [double] -or $payload.rate_limits.seven_day -is [int]) {
        $pct = [double]$payload.rate_limits.seven_day
    } elseif ($payload.rate_limits.seven_day -is [psobject]) {
        if ($null -ne $payload.rate_limits.seven_day.used_percentage) {
            $pct = [double]$payload.rate_limits.seven_day.used_percentage
        }
        $resetsAt = $payload.rate_limits.seven_day.resets_at
    }
    $bar = Get-Bar -pct $pct -width 8 -activeColor $C_SLATE
    $cVal = if ($pct -ge 85.0) { $C_ALERT } elseif ($pct -ge 65.0) { $C_WARN } else { $C_SLATE }
    $resetStr = ""
    if ($resetsAt) {
        $localTime = [DateTimeOffset]::FromUnixTimeSeconds([int64]$resetsAt).ToLocalTime()
        $resetStr = " ${C_MUTED}($($localTime.ToString('ddd HH:mm')))${RESET}"
    }
    $line2Parts += "${C_MUTED}7d:${RESET} ${bar} ${cVal}$([math]::Round($pct, 1))%${RESET}${resetStr}"
}

$line2Parts += "${C_CLAUDE}claude${RESET}"
$line2 = ($line2Parts -join $C_SEP)

Write-Output $line1
Write-Output $line2
