# Interactive AI Classification Tool
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Interactive AI Classification Tool" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Type invoice descriptions and see AI classification!" -ForegroundColor Yellow
Write-Host "Type 'exit' to quit" -ForegroundColor Gray
Write-Host ""

while ($true) {
    Write-Host "Enter description: " -NoNewline -ForegroundColor Green
    $description = Read-Host

    if ($description -eq "exit" -or $description -eq "") {
        Write-Host "Goodbye!" -ForegroundColor Cyan
        break
    }

    Write-Host "Enter amount (default 100): " -NoNewline -ForegroundColor Green
    $amountInput = Read-Host
    $amount = if ($amountInput) { [decimal]$amountInput } else { 100.00 }

    Write-Host ""
    Write-Host "Classifying..." -ForegroundColor Yellow

    $body = @{
        tenant_id = "00000000-0000-0000-0000-000000000001"
        invoice_id = "INTERACTIVE-$(Get-Random)"
        transaction_type = "AP"
        lines = @(
            @{
                line_number = 1
                description = $description
                amount = $amount
                quantity = 1
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8001/classify" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 5

        if ($response.suggestions -and $response.suggestions.Count -gt 0) {
            $suggestion = $response.suggestions[0]
            Write-Host ""
            Write-Host "RESULT:" -ForegroundColor Cyan -BackgroundColor DarkBlue
            Write-Host "  Account: " -NoNewline -ForegroundColor White
            Write-Host "$($suggestion.account_code) - $($suggestion.account_name)" -ForegroundColor Green
            Write-Host "  Confidence: " -NoNewline -ForegroundColor White
            Write-Host "$([math]::Round($suggestion.confidence_score * 100, 1))%" -ForegroundColor Green
            Write-Host "  Reasoning: " -NoNewline -ForegroundColor White
            Write-Host "$($suggestion.reasoning)" -ForegroundColor Gray
            Write-Host ""
        } else {
            Write-Host "  No suggestions returned" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ERROR: $_" -ForegroundColor Red
    }

    Write-Host "---" -ForegroundColor DarkGray
    Write-Host ""
}
