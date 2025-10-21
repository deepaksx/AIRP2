# ChatERP Query Verification Script
# Tests vendor and customer balance queries to verify correct data

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ChatERP Query Verification Test" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$TENANT_ID = "00000000-0000-0000-0000-000000000001"
$API_URL = "http://localhost:3008/api/query"

# Test 1: Vendor Balances (GL Query)
Write-Host "[TEST 1] Vendor Balances from GL..." -ForegroundColor Yellow

$vendorQuery = @{
    query = @"
SELECT v.vendor_code, v.vendor_name, v.payment_terms,
       COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) as balance,
       COUNT(DISTINCT je.entry_id) as invoice_count
FROM vendors v
LEFT JOIN journal_entry_lines jel ON jel.dimension_1::text = v.vendor_id::text
LEFT JOIN journal_entries je ON jel.entry_id = je.entry_id
LEFT JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
WHERE v.tenant_id='$TENANT_ID' AND v.status='active'
  AND (coa.account_code = '2100' OR coa.account_code IS NULL)
  AND (je.status = 'posted' OR je.status IS NULL)
GROUP BY v.vendor_id, v.vendor_code, v.vendor_name, v.payment_terms
ORDER BY balance DESC
"@
} | ConvertTo-Json

try {
    $vendorResponse = Invoke-RestMethod -Uri $API_URL -Method Post -Body $vendorQuery -ContentType "application/json"

    Write-Host "`nVendor Balances:" -ForegroundColor Green
    Write-Host "----------------" -ForegroundColor Green

    $totalAP = 0
    foreach ($vendor in $vendorResponse) {
        $balance = [decimal]$vendor.balance
        $totalAP += $balance
        Write-Host ("{0,-30} {1,15:N2} AED  ({2} invoices)" -f $vendor.vendor_name, $balance, $vendor.invoice_count)
    }

    Write-Host ("="*60) -ForegroundColor Green
    Write-Host ("Total AP (Sub-Ledger): {0,15:N2} AED" -f $totalAP) -ForegroundColor Cyan

    if ($totalAP -eq 353557.05) {
        Write-Host "✅ CORRECT! Expected: 353,557.05 AED`n" -ForegroundColor Green
    } else {
        Write-Host "❌ WRONG! Expected: 353,557.05 AED, Got: $($totalAP:N2) AED`n" -ForegroundColor Red
    }

} catch {
    Write-Host "❌ Error querying vendors: $_`n" -ForegroundColor Red
}

# Test 2: GL Account 2100 Balance
Write-Host "[TEST 2] GL Account 2100 Balance..." -ForegroundColor Yellow

$glAPQuery = @{
    query = @"
SELECT COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) as gl_balance
FROM journal_entry_lines jel
JOIN journal_entries je ON jel.entry_id = je.entry_id
JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
WHERE coa.account_code = '2100'
  AND je.tenant_id = '$TENANT_ID'
  AND je.status = 'posted'
"@
} | ConvertTo-Json

try {
    $glAPResponse = Invoke-RestMethod -Uri $API_URL -Method Post -Body $glAPQuery -ContentType "application/json"
    $glAPBalance = [decimal]$glAPResponse[0].gl_balance

    Write-Host ("GL Account 2100 Balance: {0,15:N2} AED" -f $glAPBalance) -ForegroundColor Cyan

    $variance = [Math]::Abs($glAPBalance - $totalAP)
    if ($variance -lt 0.01) {
        Write-Host "✅ BALANCED! Variance: $($variance:N2) AED`n" -ForegroundColor Green
    } else {
        Write-Host "⚠️ OUT OF BALANCE! Variance: $($variance:N2) AED`n" -ForegroundColor Red
    }

} catch {
    Write-Host "❌ Error querying GL Account 2100: $_`n" -ForegroundColor Red
}

# Test 3: Customer Balances (GL Query)
Write-Host "[TEST 3] Customer Balances from GL..." -ForegroundColor Yellow

$customerQuery = @{
    query = @"
SELECT c.customer_code, c.customer_name, c.payment_terms,
       COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0) as balance,
       COUNT(DISTINCT je.entry_id) as invoice_count
FROM customers c
LEFT JOIN journal_entry_lines jel ON jel.dimension_2::text = c.customer_id::text
LEFT JOIN journal_entries je ON jel.entry_id = je.entry_id
LEFT JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
WHERE c.tenant_id='$TENANT_ID' AND c.status='active'
  AND (coa.account_code = '1200' OR coa.account_code IS NULL)
  AND (je.status = 'posted' OR je.status IS NULL)
GROUP BY c.customer_id, c.customer_code, c.customer_name, c.payment_terms
ORDER BY balance DESC
"@
} | ConvertTo-Json

try {
    $customerResponse = Invoke-RestMethod -Uri $API_URL -Method Post -Body $customerQuery -ContentType "application/json"

    Write-Host "`nCustomer Balances:" -ForegroundColor Green
    Write-Host "------------------" -ForegroundColor Green

    $totalAR = 0
    foreach ($customer in $customerResponse) {
        $balance = [decimal]$customer.balance
        $totalAR += $balance
        Write-Host ("{0,-30} {1,15:N2} AED  ({2} invoices)" -f $customer.customer_name, $balance, $customer.invoice_count)
    }

    Write-Host ("="*60) -ForegroundColor Green
    Write-Host ("Total AR (Sub-Ledger): {0,15:N2} AED" -f $totalAR) -ForegroundColor Cyan

    if ($totalAR -eq 540567.30) {
        Write-Host "✅ CORRECT! Expected: 540,567.30 AED`n" -ForegroundColor Green
    } else {
        Write-Host "❌ WRONG! Expected: 540,567.30 AED, Got: $($totalAR:N2) AED`n" -ForegroundColor Red
    }

} catch {
    Write-Host "❌ Error querying customers: $_`n" -ForegroundColor Red
}

# Test 4: GL Account 1200 Balance
Write-Host "[TEST 4] GL Account 1200 Balance..." -ForegroundColor Yellow

$glARQuery = @{
    query = @"
SELECT COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0) as gl_balance
FROM journal_entry_lines jel
JOIN journal_entries je ON jel.entry_id = je.entry_id
JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
WHERE coa.account_code = '1200'
  AND je.tenant_id = '$TENANT_ID'
  AND je.status = 'posted'
"@
} | ConvertTo-Json

try {
    $glARResponse = Invoke-RestMethod -Uri $API_URL -Method Post -Body $glARQuery -ContentType "application/json"
    $glARBalance = [decimal]$glARResponse[0].gl_balance

    Write-Host ("GL Account 1200 Balance: {0,15:N2} AED" -f $glARBalance) -ForegroundColor Cyan

    $variance = [Math]::Abs($glARBalance - $totalAR)
    if ($variance -lt 0.01) {
        Write-Host "✅ BALANCED! Variance: $($variance:N2) AED`n" -ForegroundColor Green
    } else {
        Write-Host "⚠️ OUT OF BALANCE! Variance: $($variance:N2) AED`n" -ForegroundColor Red
    }

} catch {
    Write-Host "❌ Error querying GL Account 1200: $_`n" -ForegroundColor Red
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Expected Results:" -ForegroundColor White
Write-Host "  Vendor Balances:  353,557.05 AED" -ForegroundColor White
Write-Host "  Customer Balances: 540,567.30 AED" -ForegroundColor White
Write-Host "`nActual Results:" -ForegroundColor White
Write-Host ("  Vendor Balances:  {0,12:N2} AED" -f $totalAP) -ForegroundColor White
Write-Host ("  Customer Balances: {0,12:N2} AED" -f $totalAR) -ForegroundColor White
Write-Host "`nVerdict:" -ForegroundColor White

if ($totalAP -eq 353557.05 -and $totalAR -eq 540567.30) {
    Write-Host "✅ ALL QUERIES ARE CORRECT!" -ForegroundColor Green
    Write-Host "`nIf ChatERP still shows wrong values, the issue is BROWSER CACHE." -ForegroundColor Yellow
    Write-Host "User must:" -ForegroundColor Yellow
    Write-Host "  1. Close ALL browser tabs/windows" -ForegroundColor Yellow
    Write-Host "  2. Reopen browser" -ForegroundColor Yellow
    Write-Host "  3. Press Ctrl+Shift+Delete" -ForegroundColor Yellow
    Write-Host "  4. Clear 'Cached images and files'" -ForegroundColor Yellow
    Write-Host "  5. Reopen ChatERP" -ForegroundColor Yellow
} else {
    Write-Host "❌ QUERIES RETURNING WRONG DATA!" -ForegroundColor Red
    Write-Host "This indicates a database or query problem." -ForegroundColor Red
}

Write-Host "`n========================================`n" -ForegroundColor Cyan
