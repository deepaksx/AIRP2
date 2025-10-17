# AI Auto-Accounting Classification Tests
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "AI Auto-Accounting Classification Tests" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$tests = @(
    @{
        Name = "Office Supplies"
        Description = "Office supplies - printer paper and pens"
        Amount = 150.00
    },
    @{
        Name = "Rent Expense"
        Description = "Monthly office rent payment"
        Amount = 5000.00
    },
    @{
        Name = "Marketing"
        Description = "Facebook advertising campaign"
        Amount = 2500.00
    },
    @{
        Name = "Utilities"
        Description = "DEWA electricity bill"
        Amount = 450.00
    },
    @{
        Name = "IT Equipment"
        Description = "Dell laptop computer"
        Amount = 1500.00
    },
    @{
        Name = "Cloud Hosting"
        Description = "AWS cloud hosting services"
        Amount = 850.00
    }
)

$testNumber = 1
foreach ($test in $tests) {
    Write-Host "[$testNumber/$($tests.Count)] Testing: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($test.Description)" -ForegroundColor White

    $body = @{
        tenant_id = "00000000-0000-0000-0000-000000000001"
        invoice_id = "TEST-$testNumber"
        transaction_type = "AP"
        lines = @(
            @{
                line_number = 1
                description = $test.Description
                amount = $test.Amount
                quantity = 1
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8001/classify" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 5

        if ($response.suggestions -and $response.suggestions.Count -gt 0) {
            $suggestion = $response.suggestions[0]
            Write-Host "  AI Suggestion: " -NoNewline -ForegroundColor Green
            Write-Host "$($suggestion.account_code) - $($suggestion.account_name)" -ForegroundColor Cyan
            Write-Host "  Confidence: " -NoNewline -ForegroundColor Green
            Write-Host "$([math]::Round($suggestion.confidence_score * 100, 1))%" -ForegroundColor Cyan
            Write-Host "  Reasoning: " -NoNewline -ForegroundColor Green
            Write-Host "$($suggestion.reasoning)" -ForegroundColor Gray
            Write-Host "  Processing Time: " -NoNewline -ForegroundColor Green
            Write-Host "$([math]::Round($response.processing_time_ms, 2))ms" -ForegroundColor Gray
        } else {
            Write-Host "  No suggestions returned" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ERROR: $_" -ForegroundColor Red
    }

    Write-Host ""
    $testNumber++
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Chart of Accounts Reference" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "1000 - Cash" -ForegroundColor Gray
Write-Host "1200 - Accounts Receivable" -ForegroundColor Gray
Write-Host "2100 - Accounts Payable" -ForegroundColor Gray
Write-Host "4000 - Revenue - Product Sales" -ForegroundColor Gray
Write-Host "5100 - Cost of Goods Sold" -ForegroundColor Gray
Write-Host "5200 - Salaries & Wages" -ForegroundColor Gray
Write-Host "5300 - Rent Expense" -ForegroundColor Gray
Write-Host "5400 - Utilities" -ForegroundColor Gray
Write-Host "5500 - Office Supplies" -ForegroundColor Gray
Write-Host "5600 - IT & Software" -ForegroundColor Gray
Write-Host "5700 - Marketing & Advertising" -ForegroundColor Gray
Write-Host ""
