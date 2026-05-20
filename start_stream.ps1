# ============================================================
# start_stream.ps1 — One-click stream launcher (unattended-safe)
# Starts: Node.js, ngrok, anti-idle guard, disables PC sleep (AC)
# Patches SpawnScript with the ngrok URL.
# ============================================================

$projectDir  = "C:\Users\owner\Documents\Cursor Projects\live_roblox"
$spawnScript = "$projectDir\SpawnScript.lua"
$antiIdlePs1 = "$projectDir\anti_idle.ps1"
$pidFile     = "$projectDir\.anti_idle.pid"

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "   ROBLOX TIKTOK STREAM LAUNCHER" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# ── Kill any leftover processes ─────────────────────────────
Write-Host "[1/6] Cleaning up old processes..." -ForegroundColor Yellow
Write-Host "      (Only restart node if queue/TikTok is broken — restarts cause rate limits)" -ForegroundColor DarkGray
if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($oldPid) { Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue }
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}
Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
Stop-Process -Name "node"  -ErrorAction SilentlyContinue
Stop-Process -Name "ngrok" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# ── Prevent PC sleep while plugged in (required for unattended) ─
Write-Host "[2/6] Disabling sleep on AC power..." -ForegroundColor Yellow
powercfg /change monitor-timeout-ac 0      2>$null
powercfg /change standby-timeout-ac 0      2>$null
powercfg /change hibernate-timeout-ac 0    2>$null

# ── Start Node.js server ────────────────────────────────────
Write-Host "[3/6] Starting Node.js server..." -ForegroundColor Yellow
Start-Process -FilePath "node" -ArgumentList "server.js" `
    -WorkingDirectory $projectDir -WindowStyle Minimized
Start-Sleep -Seconds 2

# ── Start ngrok ─────────────────────────────────────────────
Write-Host "[4/6] Starting ngrok tunnel..." -ForegroundColor Yellow
Start-Process -FilePath "ngrok" -ArgumentList "http 3000" -WindowStyle Minimized
Start-Sleep -Seconds 3

# ── Start anti-idle (prevents Roblox 20-min kick) ───────────
Write-Host "[5/6] Starting anti-idle guard..." -ForegroundColor Yellow
Start-Process -FilePath "powershell" `
    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$antiIdlePs1`"" `
    -WindowStyle Hidden
Start-Sleep -Seconds 1

# ── Patch SpawnScript with ngrok URL ────────────────────────
Write-Host "[6/6] Fetching ngrok URL and patching SpawnScript.lua..." -ForegroundColor Yellow

$ngrokUrl = $null
for ($i = 0; $i -lt 10; $i++) {
    try {
        $tunnels  = Invoke-RestMethod -Uri "http://localhost:4040/api/tunnels" -ErrorAction Stop
        $ngrokUrl = ($tunnels.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1).public_url
        if ($ngrokUrl) { break }
    } catch {}
    Start-Sleep -Seconds 1
}

if (-not $ngrokUrl) {
    Write-Host "ERROR: Could not get ngrok URL. Is ngrok installed?" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$content = Get-Content $spawnScript -Raw
$content = $content -replace 'local SERVER_URL\s*=\s*"[^"]*"', "local SERVER_URL      = `"$ngrokUrl`""
Set-Content $spawnScript -Value $content -NoNewline

Write-Host ""
Write-Host "=======================================" -ForegroundColor Green
Write-Host "   ALL SYSTEMS GO (UNATTENDED MODE)" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Server    : http://localhost:3000" -ForegroundColor White
Write-Host "  Status    : http://localhost:3000/api/status" -ForegroundColor White
Write-Host "  Tunnel    : $ngrokUrl" -ForegroundColor White
Write-Host "  Anti-idle : running (check anti_idle.log)" -ForegroundColor White
Write-Host "  PC sleep  : disabled while on AC power" -ForegroundColor White
Write-Host ""
Write-Host "  BEFORE YOU LEAVE FOR WORK:" -ForegroundColor Yellow
Write-Host "  1. Publish Roblox if SpawnScript changed (Ctrl+Shift+Alt+P)" -ForegroundColor Yellow
Write-Host "  2. Open published game in Roblox Player (stay in-game)" -ForegroundColor Yellow
Write-Host "  3. Go live on TikTok" -ForegroundColor Yellow
Write-Host "  4. Leave this PC plugged in - do not close the lid" -ForegroundColor Yellow
Write-Host ""
Write-Host "  To stop everything later: run stop_stream.ps1" -ForegroundColor DarkGray
Write-Host ""
Read-Host 'Press Enter to close this window (services keep running)'
