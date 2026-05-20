# ============================================================
# start_stream.ps1 — One-click stream launcher
# Run this every time before going live.
# It starts the server, starts ngrok, auto-patches SpawnScript
# with the new URL, then reminds you to republish.
# ============================================================

$projectDir  = "C:\Users\owner\Documents\Cursor Projects\live_roblox"
$spawnScript = "$projectDir\SpawnScript.lua"

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "   ROBLOX TIKTOK STREAM LAUNCHER" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# ── Kill any leftover node / ngrok processes ────────────────
Write-Host "[1/4] Cleaning up old processes..." -ForegroundColor Yellow
Stop-Process -Name "node"  -ErrorAction SilentlyContinue
Stop-Process -Name "ngrok" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# ── Start node server in background ────────────────────────
Write-Host "[2/4] Starting Node.js server..." -ForegroundColor Yellow
Start-Process -FilePath "node" -ArgumentList "server.js" `
    -WorkingDirectory $projectDir -WindowStyle Minimized

Start-Sleep -Seconds 2

# ── Start ngrok in background ───────────────────────────────
Write-Host "[3/4] Starting ngrok tunnel..." -ForegroundColor Yellow
Start-Process -FilePath "ngrok" -ArgumentList "http 3000" -WindowStyle Minimized
Start-Sleep -Seconds 3

# ── Get new ngrok URL and patch SpawnScript ─────────────────
Write-Host "[4/4] Fetching ngrok URL and patching SpawnScript.lua..." -ForegroundColor Yellow

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

# Patch SERVER_URL in SpawnScript.lua
$content = Get-Content $spawnScript -Raw
$content = $content -replace 'local SERVER_URL\s*=\s*"[^"]*"', "local SERVER_URL      = `"$ngrokUrl`""
Set-Content $spawnScript -Value $content -NoNewline

Write-Host ""
Write-Host "=======================================" -ForegroundColor Green
Write-Host "   ALL SYSTEMS GO!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Server  : http://localhost:3000" -ForegroundColor White
Write-Host "  Tunnel  : $ngrokUrl" -ForegroundColor White
Write-Host "  Status  : http://localhost:3000/api/status" -ForegroundColor White
Write-Host ""
Write-Host "  ACTION REQUIRED:" -ForegroundColor Yellow
Write-Host "  1. Open Roblox Studio" -ForegroundColor Yellow
Write-Host "  2. File > Publish to Roblox (Ctrl+Shift+Alt+P)" -ForegroundColor Yellow
Write-Host "  3. Then open Roblox Player and go live!" -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter when you've republished to close this window"
