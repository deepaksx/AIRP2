$TENANT = "00000000-0000-0000-0000-000000000001"
$BASE_URL = "http://localhost"
$ERRORS = 0
$SUCCESS = 0

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "AIRP v2.0 - Comprehensive Page API Testing" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

function Test-API {
    param(
        [string]$Name,
        [string]$Url,
        [int]$ExpectedStatus = 200
    )

    Write-Host -NoNewline "Testing $Name... "

    try {
        $response = Invoke-WebRequest -Uri $Url -Method GET -UseBasicParsing -ErrorAction Stop
        $status = $response.StatusCode

        if ($status -eq $ExpectedStatus) {
            Write-Host "✅ OK (HTTP $status)" -ForegroundColor Green
            $script:SUCCESS++
        } else {
            Write-Host "❌ FAIL (HTTP $status, expected $ExpectedStatus)" -ForegroundColor Red
            $script:ERRORS++
        }
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        if ($null -eq $status) { $status = "ERROR" }
        Write-Host "❌ FAIL (HTTP $status)" -ForegroundColor Red
        $script:ERRORS++
    }
}

Write-Host "=== 1. MASTER DATA APIs ===" -ForegroundColor Yellow
Test-API "Chart of Accounts" "$BASE_URL:3001/chart-of-accounts?tenant_id=$TENANT"
Test-API "Vendors List" "$BASE_URL:3003/vendors?tenant_id=$TENANT"
Test-API "Customers List" "$BASE_URL:3004/customers?tenant_id=$TENANT"
Test-API "Bank Accounts" "$BASE_URL:3005/bank-accounts?tenant_id=$TENANT"
Write-Host ""

Write-Host "=== 2. EVENT STORE APIs ===" -ForegroundColor Yellow
Test-API "Journal Entry Events" "$BASE_URL:3001/events/by-tenant/$TENANT?eventType=JournalEntryPosted"
Test-API "All Events" "$BASE_URL:3001/events/by-tenant/$TENANT"
Test-API "Event Stats" "$BASE_URL:3001/events/stats?tenantId=$TENANT"
Write-Host ""

Write-Host "=== 3. AP (Accounts Payable) APIs ===" -ForegroundColor Yellow
Test-API "AP Invoices" "$BASE_URL:3003/invoices?tenant_id=$TENANT"
Test-API "Vendor Ledger" "$BASE_URL:3008/reports/vendor-ledger?tenant_id=$TENANT"
Write-Host ""

Write-Host "=== 4. AR (Accounts Receivable) APIs ===" -ForegroundColor Yellow
Test-API "AR Invoices" "$BASE_URL:3004/invoices?tenant_id=$TENANT"
Test-API "Customer Ledger" "$BASE_URL:3008/reports/customer-ledger?tenant_id=$TENANT"
Write-Host ""

Write-Host "=== 5. REPORTING APIs ===" -ForegroundColor Yellow
Test-API "Trial Balance" "$BASE_URL:3008/reports/trial-balance?tenant_id=$TENANT"
Test-API "Account Balances" "$BASE_URL:3008/reports/account-balances?tenant_id=$TENANT"
Test-API "Income Statement" "$BASE_URL:3008/reports/income-statement?tenant_id=$TENANT&start_date=2025-01-01&end_date=2025-12-31"
Test-API "Balance Sheet" "$BASE_URL:3008/reports/balance-sheet?tenant_id=$TENANT&as_of_date=2025-12-31"
Test-API "Cash Flow Statement" "$BASE_URL:3008/reports/cash-flow?tenant_id=$TENANT&start_date=2025-01-01&end_date=2025-12-31"
Write-Host ""

Write-Host "=== 6. AI SERVICES (Optional) ===" -ForegroundColor Yellow
Test-API "AI Classification" "$BASE_URL:8001/health"
Test-API "AI Reconciliation" "$BASE_URL:8002/health"
Test-API "AI Policy Advisor" "$BASE_URL:8003/health"
Test-API "AI Narrative" "$BASE_URL:8004/health"
Test-API "AI Cash Flow" "$BASE_URL:8005/health"
Test-API "AI Query Parser" "$BASE_URL:8006/health"
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "✅ Successful: $SUCCESS" -ForegroundColor Green
Write-Host "❌ Failed: $ERRORS" -ForegroundColor Red
Write-Host ""

if ($ERRORS -eq 0) {
    Write-Host "🎉 ALL TESTS PASSED - 100% FUNCTIONAL" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  FAILURES DETECTED - FIXING REQUIRED" -ForegroundColor Yellow
    exit 1
}
