# ============================================================
# setup_euler_key.ps1 — One-time Euler Stream API key setup
# Free tier: https://www.eulerstream.com/register
# Fixes TikTok "rate_limit_account_hour" errors.
# ============================================================

$projectDir = "C:\Users\owner\Documents\Cursor Projects\live_roblox"
$envFile    = Join-Path $projectDir ".env"

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "   EULER STREAM API KEY SETUP" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Sign up free (Google/GitHub/email):" -ForegroundColor Yellow
Write-Host "   https://www.eulerstream.com/register" -ForegroundColor White
Write-Host ""
Write-Host "2. Open dashboard -> create/copy your API key:" -ForegroundColor Yellow
Write-Host "   https://www.eulerstream.com/dashboard" -ForegroundColor White
Write-Host ""

$open = Read-Host "Open signup page in browser now? (Y/n)"
if ($open -ne "n" -and $open -ne "N") {
    Start-Process "https://www.eulerstream.com/register"
    Start-Sleep -Seconds 1
    Start-Process "https://www.eulerstream.com/dashboard"
}

Write-Host ""
$key = Read-Host "Paste your Euler API key here"
$key = $key.Trim()

if ($key.Length -lt 8) {
    Write-Host "ERROR: Key looks too short. Copy the full key from the dashboard." -ForegroundColor Red
    exit 1
}

$content = @"
# Euler Stream sign API key — fixes TikTok rate limits
# Get free key: https://www.eulerstream.com/dashboard
TIKTOK_SIGN_API_KEY=$key
"@

Set-Content -Path $envFile -Value $content -Encoding UTF8

Write-Host ""
Write-Host "Saved to .env" -ForegroundColor Green
Write-Host "Restarting Node with new key..." -ForegroundColor Yellow

Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
Stop-Process -Name "node" -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Start-Process -FilePath "node" -ArgumentList "server.js" `
    -WorkingDirectory $projectDir -WindowStyle Normal

Start-Sleep -Seconds 8

try {
    $status = Invoke-RestMethod -Uri "http://localhost:3000/api/status"
    Write-Host ""
    Write-Host "TikTok connected : $($status.tiktokConnected)" -ForegroundColor $(if ($status.tiktokConnected) { "Green" } else { "Yellow" })
    if ($status.tiktokLastError) {
        Write-Host "Last error      : $($status.tiktokLastError.Substring(0, [Math]::Min(120, $status.tiktokLastError.Length)))..." -ForegroundColor DarkYellow
    }
    if ($status.tiktokConnected) {
        Write-Host ""
        Write-Host "SUCCESS — chat usernames should queue now. Go live on TikTok and test!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Key saved. If not connected yet:" -ForegroundColor Yellow
        Write-Host "  - Make sure you are LIVE on TikTok" -ForegroundColor Yellow
        Write-Host "  - Wait 1 min if you were rate-limited earlier" -ForegroundColor Yellow
        Write-Host "  - Check the Node window for [TikTok] Connected!" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not reach Node — start manually: node server.js" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to close"
