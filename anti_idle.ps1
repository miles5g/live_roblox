# ============================================================
# anti_idle.ps1 - Keeps Roblox Player AND TikTok Live awake
# Roblox: mouse + Shift every 3 min (20-min idle kick)
# TikTok: LIVE Studio (preferred) or Chrome fallback, every 2 min
# Started automatically by start_stream.ps1 - leave it running.
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

$projectDir        = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile           = Join-Path $projectDir ".anti_idle.pid"
$robloxIntervalSec = 180   # 3 min - Roblox idle kick is ~20 min
$tiktokIntervalSec = 120   # 2 min - TikTok unattended-live checks are aggressive
$loopSec           = 30    # how often we check timers

Set-Content -Path $pidFile -Value $PID

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class IdleGuard {
    public const int INPUT_MOUSE = 0;
    public const int INPUT_KEYBOARD = 1;
    public const uint MOUSEEVENTF_MOVE = 0x0001;
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const ushort VK_SHIFT = 0x10;

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT {
        public int type;
        public InputUnion U;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct InputUnion {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll")] public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
}

"@

$inputSize = [System.Runtime.InteropServices.Marshal]::SizeOf([IdleGuard+INPUT])

function Focus-WindowHandle($handle) {
    if (-not $handle -or $handle -eq 0) { return $false }
    [IdleGuard]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 150
    return $true
}

function Send-MouseWiggle {
    $move = New-Object IdleGuard+INPUT
    $move.type = [IdleGuard]::INPUT_MOUSE
    $move.U.mi.dx = 3
    $move.U.mi.dy = 1
    $move.U.mi.dwFlags = [IdleGuard]::MOUSEEVENTF_MOVE
    [IdleGuard]::SendInput(1, @($move), $inputSize) | Out-Null
    Start-Sleep -Milliseconds 50
    $moveBack = New-Object IdleGuard+INPUT
    $moveBack.type = [IdleGuard]::INPUT_MOUSE
    $moveBack.U.mi.dx = -3
    $moveBack.U.mi.dy = -1
    $moveBack.U.mi.dwFlags = [IdleGuard]::MOUSEEVENTF_MOVE
    [IdleGuard]::SendInput(1, @($moveBack), $inputSize) | Out-Null
}

function Send-ShiftTap {
    $keyDown = New-Object IdleGuard+INPUT
    $keyDown.type = [IdleGuard]::INPUT_KEYBOARD
    $keyDown.U.ki.wVk = [IdleGuard]::VK_SHIFT
    [IdleGuard]::SendInput(1, @($keyDown), $inputSize) | Out-Null
    Start-Sleep -Milliseconds 40
    $keyUp = New-Object IdleGuard+INPUT
    $keyUp.type = [IdleGuard]::INPUT_KEYBOARD
    $keyUp.U.ki.wVk = [IdleGuard]::VK_SHIFT
    $keyUp.U.ki.dwFlags = [IdleGuard]::KEYEVENTF_KEYUP
    [IdleGuard]::SendInput(1, @($keyUp), $inputSize) | Out-Null
}

function Find-RobloxPlayer {
    Get-Process -Name "RobloxPlayerBeta" -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -First 1
}

function Find-TikTokStudio {
    # Known TikTok LIVE Studio process names (varies by install/version)
    foreach ($name in @('TikTokLiveStudio', 'TikTokLiveStudioBeta', 'LIVEStudio', 'TikTok LIVE Studio')) {
        $proc = Get-Process -Name $name -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 } |
            Select-Object -First 1
        if ($proc) { return $proc }
    }

    # Match by window title if process name differs
    return Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.MainWindowHandle -ne 0
            -and $_.MainWindowTitle -match '(?i)TikTok LIVE Studio|LIVE Studio'
            -and $_.ProcessName -notmatch '^(chrome|msedge|RobloxPlayerBeta)$'
        } |
        Select-Object -First 1
}

function Find-TikTokBrowser {
    # Chrome/Edge fallback when Studio is not open (Tampermonkey bridge tab)
    $candidates = Get-Process chrome, msedge -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match '(?i)tiktok' }

    $live = $candidates | Where-Object { $_.MainWindowTitle -match '(?i)live' } | Select-Object -First 1
    if ($live) { return $live }
    return $candidates | Select-Object -First 1
}

function Find-TikTokTarget {
    $studio = Find-TikTokStudio
    if ($studio) { return @{ Proc = $studio; Source = 'LIVE Studio' } }

    $browser = Find-TikTokBrowser
    if ($browser) { return @{ Proc = $browser; Source = 'Chrome fallback' } }

    return $null
}

function Nudge-Roblox {
    $proc = Find-RobloxPlayer
    if (-not $proc) {
        Log "Roblox: Player not running - skipped"
        return $false
    }
    Focus-WindowHandle $proc.MainWindowHandle | Out-Null
    Send-MouseWiggle
    Send-ShiftTap
    Log "Roblox: input sent ($($proc.MainWindowTitle))"
    return $true
}

function Nudge-TikTok {
    $target = Find-TikTokTarget
    if (-not $target) {
        Log "TikTok: LIVE Studio not found - open TikTok LIVE Studio (or Chrome live tab as backup)"
        return $false
    }
    $proc = $target.Proc
    $source = $target.Source
    Focus-WindowHandle $proc.MainWindowHandle | Out-Null
    # Mouse only - avoid Shift typing into Studio UI or chat
    Send-MouseWiggle
    Start-Sleep -Milliseconds 80
    Send-MouseWiggle
    Log "TikTok: input sent via $source ($($proc.MainWindowTitle))"
    return $true
}

$logFile = Join-Path $projectDir "anti_idle.log"
function Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Add-Content -Path $logFile -Value $line
}

Log "Anti-idle started (PID $PID) - Roblox every ${robloxIntervalSec}s, TikTok Studio every ${tiktokIntervalSec}s"

$lastRoblox = [datetime]::MinValue
$lastTikTok = [datetime]::MinValue

# Prime both shortly after start
Start-Sleep -Seconds 5
Nudge-Roblox | Out-Null
Start-Sleep -Seconds 2
Nudge-TikTok | Out-Null
$lastRoblox = Get-Date
$lastTikTok = Get-Date

while ($true) {
    Start-Sleep -Seconds $loopSec
    $now = Get-Date

    if (($now - $lastRoblox).TotalSeconds -ge $robloxIntervalSec) {
        if (Nudge-Roblox) { $lastRoblox = $now }
    }

    if (($now - $lastTikTok).TotalSeconds -ge $tiktokIntervalSec) {
        if (Nudge-TikTok) { $lastTikTok = $now }
    }
}
