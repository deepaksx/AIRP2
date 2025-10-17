# Quick Interactive AI Classification Test
param(
    [string]$Description = ""
)

if ($Description -eq "") {
    Write-Host "Enter a description to classify: " -NoNewline -ForegroundColor Cyan
    $Description = Read-Host
}

Write-Host ""
Write-Host "Classifying: $Description" -ForegroundColor Yellow
Write-Host ""

$body = @{
    tenant_id = "00000000-0000-0000-0000-000000000001"
    invoice_id = "QUICK-$(Get-Date -Format 'HHmmss')"
    transaction_type = "AP"
    lines = @(
        @{
            line_number = 1
            description = $Description
            amount = 100.00
            quantity = 1
        }
    )
} | ConvertTo-Json -Depth 10

try {
    $response = Invoke-RestMethod -Uri "http://localhost:8001/classify" -Method POST -Body $body -ContentType "application/json"

    $suggestion = $response.suggestions[0]

    Write-Host "RESULT:" -ForegroundColor Green -BackgroundColor Black
    Write-Host "  Account Code: " -NoNewline
    Write-Host "$($suggestion.account_code)" -ForegroundColor Cyan
    Write-Host "  Account Name: " -NoNewline
    Write-Host "$($suggestion.account_name)" -ForegroundColor Cyan
    Write-Host "  Confidence:   " -NoNewline
    Write-Host "$([math]::Round($suggestion.confidence_score * 100, 1))%" -ForegroundColor $(if ($suggestion.confidence_score -gt 0.5) { "Green" } else { "Yellow" })
    Write-Host "  Reasoning:    " -NoNewline
    Write-Host "$($suggestion.reasoning)" -ForegroundColor Gray
    Write-Host ""

} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
