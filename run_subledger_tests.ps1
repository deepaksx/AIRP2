# AIRP v2 - Sub-Ledger Management Automated Tests
# Test Iteration 3: Complete automation without interruptions

Write-Host "=== AIRP v2 - Sub-Ledger Management Tests ===" -ForegroundColor Cyan
Write-Host "Starting tests at $(Get-Date)" -ForegroundColor Yellow
Write-Host ""

$baseUrl = "http://localhost:3008/api/query"
$apUrl = "http://localhost:3003/invoices"
$arUrl = "http://localhost:3004/invoices"
$tenantId = "00000000-0000-0000-0000-000000000001"
$vendorId = "cc1e22ff-ab11-431d-8ad0-d57528ea639d"
$customerId = "593adf90-91f1-4da8-a5b6-0912416351e4"

# TEST-033: Customer ledger to GL 1200 reconciliation
Write-Host "TEST-033: Customer ledger to GL 1200 reconciliation" -ForegroundColor Green
$query = @{
    query = "SELECT (SELECT COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0) FROM journal_entry_lines jel JOIN journal_entries je ON jel.entry_id = je.entry_id WHERE jel.dimension_2::text = '$customerId' AND je.tenant_id = '$tenantId' AND je.status = 'posted') as customer_subledger, (SELECT COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0) FROM journal_entry_lines jel JOIN journal_entries je ON jel.entry_id = je.entry_id JOIN chart_of_accounts coa ON jel.account_id = coa.account_id WHERE coa.account_code = '1200' AND je.tenant_id = '$tenantId' AND je.status = 'posted') as gl_ar_balance"
} | ConvertTo-Json

$result = Invoke-RestMethod -Uri $baseUrl -Method POST -ContentType "application/json" -Body $query
Write-Host "Customer Sub-Ledger: $($result[0].customer_subledger)" -ForegroundColor White
Write-Host "GL AR Balance (1200): $($result[0].gl_ar_balance)" -ForegroundColor White
Write-Host ""

# TEST-034: AP Aging Report
Write-Host "TEST-034: AP Aging Report" -ForegroundColor Green
$agingUrl = "http://localhost:3008/reports/aging/ap?tenant_id=$tenantId"
$aging = Invoke-RestMethod -Uri $agingUrl -Method GET
Write-Host "Total AP Outstanding: $($aging.total_outstanding)" -ForegroundColor White
Write-Host "Vendor Count: $($aging.vendor_count)" -ForegroundColor White
Write-Host ""

# TEST-035: AR Aging Report
Write-Host "TEST-035: AR Aging Report" -ForegroundColor Green
$arAgingUrl = "http://localhost:3008/reports/aging/ar?tenant_id=$tenantId"
$arAging = Invoke-RestMethod -Uri $arAgingUrl -Method GET
Write-Host "Total AR Outstanding: $($arAging.total_outstanding)" -ForegroundColor White
Write-Host "Customer Count: $($arAging.customer_count)" -ForegroundColor White
Write-Host ""

# TEST-036: Dimension-based tracking verification
Write-Host "TEST-036: Dimension-based tracking (vendor_id in dimension_1)" -ForegroundColor Green
$dimQuery = @{
    query = "SELECT COUNT(*) as count FROM journal_entry_lines WHERE dimension_1 IS NOT NULL AND dimension_1::text = '$vendorId'"
} | ConvertTo-Json

$dimResult = Invoke-RestMethod -Uri $baseUrl -Method POST -ContentType "application/json" -Body $dimQuery
Write-Host "Journal lines with vendor dimension: $($dimResult[0].count)" -ForegroundColor White
Write-Host ""

# TEST-037: Sub-ledger variance detection
Write-Host "TEST-037: Sub-ledger variance detection" -ForegroundColor Green
$varianceQuery = @{
    query = "SELECT (SELECT COALESCE(SUM(total_amount), 0) FROM ap_invoices WHERE tenant_id = '$tenantId') as ap_subledger_total, (SELECT ABS(COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0)) FROM journal_entry_lines jel JOIN journal_entries je ON jel.entry_id = je.entry_id JOIN chart_of_accounts coa ON jel.account_id = coa.account_id WHERE coa.account_code = '2100' AND je.tenant_id = '$tenantId' AND je.status = 'posted') as gl_ap_total"
} | ConvertTo-Json

$variance = Invoke-RestMethod -Uri $baseUrl -Method POST -ContentType "application/json" -Body $varianceQuery
$apVariance = [decimal]$variance[0].ap_subledger_total - [decimal]$variance[0].gl_ap_total
Write-Host "AP Sub-Ledger Total: $($variance[0].ap_subledger_total)" -ForegroundColor White
Write-Host "GL AP Total (2100): $($variance[0].gl_ap_total)" -ForegroundColor White
Write-Host "Variance: $apVariance" -ForegroundColor $(if ([Math]::Abs($apVariance) -lt 0.01) { "Green" } else { "Red" })
Write-Host ""

Write-Host "=== All Sub-Ledger Tests Complete ===" -ForegroundColor Cyan
Write-Host "Completed at $(Get-Date)" -ForegroundColor Yellow
