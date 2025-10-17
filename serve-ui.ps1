# Simple HTTP Server for Testing UI
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Starting Web Server for AI Classification UI" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Server starting at: http://localhost:5000" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

# Start Python HTTP server
cd C:\Dev\AIRP2
python -m http.server 5000
