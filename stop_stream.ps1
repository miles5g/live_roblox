# ============================================================
# stop_stream.ps1 — Stop node, ngrok, and anti-idle
# ============================================================

$projectDir = "C:\Users\owner\Documents\Cursor Projects\live_roblox"
$pidFile    = Join-Path $projectDir ".anti_idle.pid"

Write-Host "Stopping stream stack..." -ForegroundColor Yellow

if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($oldPid) { Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue }
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }

Stop-Process -Name "ngrok" -ErrorAction SilentlyContinue
Stop-Process -Name "node"  -ErrorAction SilentlyContinue

Write-Host "Done. Node, ngrok, and anti-idle stopped." -ForegroundColor Green
