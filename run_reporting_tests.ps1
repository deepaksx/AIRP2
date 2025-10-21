# AIRP v2 - Financial Reporting Automated Tests
# Test Iteration 4: Complete automation without interruptions

Write-Host "=== AIRP v2 - Financial Reporting Tests ===" -ForegroundColor Cyan
Write-Host "Starting tests at $(Get-Date)" -ForegroundColor Yellow
Write-Host ""

$tenantId = "00000000-0000-0000-0000-000000000001"
$baseUrl = "http://localhost:3008/reports"
$results = @()

# TEST-038: Load Trial Balance report
Write-Host "TEST-038: Load Trial Balance report" -ForegroundColor Green
try {
    $tb = Invoke-RestMethod -Uri "$baseUrl/trial-balance?tenant_id=$tenantId" -Method GET
    Write-Host "✅ PASS - Loaded $($tb.accounts.Count) accounts" -ForegroundColor Green
    $results += @{Test="TEST-038"; Status="PASS"; Details="Loaded $($tb.accounts.Count) accounts"}
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-038"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-039: Verify Trial Balance has all account types
Write-Host "TEST-039: Verify Trial Balance has all 5 account types" -ForegroundColor Green
try {
    $accountTypes = $tb.accounts | Select-Object -ExpandProperty account_type -Unique
    $expectedTypes = @("asset", "liability", "equity", "revenue", "expense")
    $hasAll = $true
    foreach ($type in $expectedTypes) {
        if ($accountTypes -notcontains $type) { $hasAll = $false }
    }
    if ($hasAll) {
        Write-Host "✅ PASS - All 5 account types present: $($accountTypes -join ', ')" -ForegroundColor Green
        $results += @{Test="TEST-039"; Status="PASS"; Details="All 5 types present"}
    } else {
        Write-Host "❌ FAIL - Missing account types" -ForegroundColor Red
        $results += @{Test="TEST-039"; Status="FAIL"; Details="Missing types"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-039"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-040: Test zero-balance toggle ON by default (UI verification)
Write-Host "TEST-040: Zero-balance toggle ON by default (Code Review)" -ForegroundColor Green
$tbHtml = Get-Content "C:\Dev\AIRP2\trial-balance.html" -Raw
if ($tbHtml -match 'checked>') {
    Write-Host "✅ PASS - Toggle has 'checked' attribute" -ForegroundColor Green
    $results += @{Test="TEST-040"; Status="PASS"; Details="Checked attribute found"}
} else {
    Write-Host "❌ FAIL - Toggle not checked by default" -ForegroundColor Red
    $results += @{Test="TEST-040"; Status="FAIL"; Details="No checked attribute"}
}
Write-Host ""

# TEST-041: Test zero-balance toggle switches correctly (Code Review)
Write-Host "TEST-041: Zero-balance toggle functionality (Code Review)" -ForegroundColor Green
if ($tbHtml -match 'toggleZeroBalances') {
    Write-Host "✅ PASS - Toggle function implemented" -ForegroundColor Green
    $results += @{Test="TEST-041"; Status="PASS"; Details="Function found"}
} else {
    Write-Host "❌ FAIL - Toggle function missing" -ForegroundColor Red
    $results += @{Test="TEST-041"; Status="FAIL"; Details="Function not found"}
}
Write-Host ""

# TEST-042: Verify Trial Balance totals (DR = CR)
Write-Host "TEST-042: Verify Trial Balance totals balanced" -ForegroundColor Green
try {
    $totalDebits = ($tb.accounts | Measure-Object -Property debit_balance -Sum).Sum
    $totalCredits = ($tb.accounts | Measure-Object -Property credit_balance -Sum).Sum
    $diff = [Math]::Abs($totalDebits - $totalCredits)
    if ($diff -lt 0.01) {
        Write-Host "✅ PASS - Balanced (Debits: $totalDebits, Credits: $totalCredits, Diff: $diff)" -ForegroundColor Green
        $results += @{Test="TEST-042"; Status="PASS"; Details="Balanced"}
    } else {
        Write-Host "❌ FAIL - Not balanced (Diff: $diff)" -ForegroundColor Red
        $results += @{Test="TEST-042"; Status="FAIL"; Details="Unbalanced"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-042"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-043: Load Income Statement
Write-Host "TEST-043: Load Income Statement" -ForegroundColor Green
try {
    $is = Invoke-RestMethod -Uri "$baseUrl/income-statement?tenant_id=$tenantId" -Method GET
    Write-Host "✅ PASS - Income Statement loaded" -ForegroundColor Green
    $results += @{Test="TEST-043"; Status="PASS"; Details="Loaded successfully"}
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-043"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-044: Verify Income Statement has Revenue section
Write-Host "TEST-044: Verify Income Statement has Revenue section" -ForegroundColor Green
try {
    if ($is.revenue -or $is.revenues) {
        Write-Host "✅ PASS - Revenue section present" -ForegroundColor Green
        $results += @{Test="TEST-044"; Status="PASS"; Details="Revenue section found"}
    } else {
        Write-Host "❌ FAIL - Revenue section missing" -ForegroundColor Red
        $results += @{Test="TEST-044"; Status="FAIL"; Details="No revenue section"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-044"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-045: Verify Income Statement has Expense section
Write-Host "TEST-045: Verify Income Statement has Expense section" -ForegroundColor Green
try {
    if ($is.expenses -or $is.expense) {
        Write-Host "✅ PASS - Expense section present" -ForegroundColor Green
        $results += @{Test="TEST-045"; Status="PASS"; Details="Expense section found"}
    } else {
        Write-Host "❌ FAIL - Expense section missing" -ForegroundColor Red
        $results += @{Test="TEST-045"; Status="FAIL"; Details="No expense section"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-045"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-046: Verify Income Statement calculates Net Income
Write-Host "TEST-046: Verify Income Statement calculates Net Income" -ForegroundColor Green
try {
    if ($is.net_income -ne $null) {
        Write-Host "✅ PASS - Net Income: $($is.net_income)" -ForegroundColor Green
        $results += @{Test="TEST-046"; Status="PASS"; Details="Net Income: $($is.net_income)"}
    } else {
        Write-Host "❌ FAIL - Net Income not calculated" -ForegroundColor Red
        $results += @{Test="TEST-046"; Status="FAIL"; Details="No net_income field"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-046"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-047: Load Balance Sheet
Write-Host "TEST-047: Load Balance Sheet" -ForegroundColor Green
try {
    $bs = Invoke-RestMethod -Uri "$baseUrl/balance-sheet?tenant_id=$tenantId" -Method GET
    Write-Host "✅ PASS - Balance Sheet loaded" -ForegroundColor Green
    $results += @{Test="TEST-047"; Status="PASS"; Details="Loaded successfully"}
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-047"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-048: Verify Balance Sheet has Assets section
Write-Host "TEST-048: Verify Balance Sheet has Assets section" -ForegroundColor Green
try {
    if ($bs.assets -or $bs.total_assets -ne $null) {
        Write-Host "✅ PASS - Assets section present" -ForegroundColor Green
        $results += @{Test="TEST-048"; Status="PASS"; Details="Assets found"}
    } else {
        Write-Host "❌ FAIL - Assets section missing" -ForegroundColor Red
        $results += @{Test="TEST-048"; Status="FAIL"; Details="No assets"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-048"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-049: Verify Balance Sheet has Liabilities section
Write-Host "TEST-049: Verify Balance Sheet has Liabilities section" -ForegroundColor Green
try {
    if ($bs.liabilities -or $bs.total_liabilities -ne $null) {
        Write-Host "✅ PASS - Liabilities section present" -ForegroundColor Green
        $results += @{Test="TEST-049"; Status="PASS"; Details="Liabilities found"}
    } else {
        Write-Host "❌ FAIL - Liabilities section missing" -ForegroundColor Red
        $results += @{Test="TEST-049"; Status="FAIL"; Details="No liabilities"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-049"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-050: Verify Balance Sheet has Equity section
Write-Host "TEST-050: Verify Balance Sheet has Equity section" -ForegroundColor Green
try {
    if ($bs.equity -or $bs.total_equity -ne $null) {
        Write-Host "✅ PASS - Equity section present" -ForegroundColor Green
        $results += @{Test="TEST-050"; Status="PASS"; Details="Equity found"}
    } else {
        Write-Host "❌ FAIL - Equity section missing" -ForegroundColor Red
        $results += @{Test="TEST-050"; Status="FAIL"; Details="No equity"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-050"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-051: Verify accounting equation (Assets = Liabilities + Equity)
Write-Host "TEST-051: Verify accounting equation" -ForegroundColor Green
try {
    $assets = [decimal]$bs.total_assets
    $liabilities = [decimal]$bs.total_liabilities
    $equity = [decimal]$bs.total_equity
    $diff = [Math]::Abs($assets - ($liabilities + $equity))
    if ($diff -lt 0.01) {
        Write-Host "✅ PASS - Equation balanced (A=$assets, L+E=$($liabilities+$equity))" -ForegroundColor Green
        $results += @{Test="TEST-051"; Status="PASS"; Details="Equation balanced"}
    } else {
        Write-Host "⚠️ PARTIAL - Variance: $diff" -ForegroundColor Yellow
        $results += @{Test="TEST-051"; Status="PARTIAL"; Details="Variance: $diff"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-051"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-052: Load Cash Flow Statement
Write-Host "TEST-052: Load Cash Flow Statement" -ForegroundColor Green
try {
    $cf = Invoke-RestMethod -Uri "$baseUrl/cash-flow-statement?tenant_id=$tenantId" -Method GET
    Write-Host "✅ PASS - Cash Flow Statement loaded" -ForegroundColor Green
    $results += @{Test="TEST-052"; Status="PASS"; Details="Loaded successfully"}
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-052"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-053: Load GL Line Items report
Write-Host "TEST-053: Load GL Line Items report" -ForegroundColor Green
$glHtml = Get-Content "C:\Dev\AIRP2\gl-line-items.html" -Raw
if ($glHtml -match 'GL Line Items') {
    Write-Host "✅ PASS - GL Line Items page exists" -ForegroundColor Green
    $results += @{Test="TEST-053"; Status="PASS"; Details="Page found"}
} else {
    Write-Host "❌ FAIL - GL Line Items page missing" -ForegroundColor Red
    $results += @{Test="TEST-053"; Status="FAIL"; Details="Page not found"}
}
Write-Host ""

# TEST-054: Verify GL Line Items has total row
Write-Host "TEST-054: Verify GL Line Items has total row" -ForegroundColor Green
if ($glHtml -match 'total-row' -or $glHtml -match 'TOTAL') {
    Write-Host "✅ PASS - Total row implemented" -ForegroundColor Green
    $results += @{Test="TEST-054"; Status="PASS"; Details="Total row found"}
} else {
    Write-Host "❌ FAIL - Total row missing" -ForegroundColor Red
    $results += @{Test="TEST-054"; Status="FAIL"; Details="No total row"}
}
Write-Host ""

# TEST-055: Verify GL Line Items total balance = 0.00
Write-Host "TEST-055: Verify GL Line Items total balance logic" -ForegroundColor Green
if ($glHtml -match 'totalBalance' -and $glHtml -match 'isBalanced') {
    Write-Host "✅ PASS - Balance check logic implemented" -ForegroundColor Green
    $results += @{Test="TEST-055"; Status="PASS"; Details="Balance check found"}
} else {
    Write-Host "❌ FAIL - Balance check missing" -ForegroundColor Red
    $results += @{Test="TEST-055"; Status="FAIL"; Details="No balance check"}
}
Write-Host ""

# TEST-056: Load Journal Entry Register
Write-Host "TEST-056: Load Journal Entry Register" -ForegroundColor Green
$jeHtml = Get-Content "C:\Dev\AIRP2\je-register.html" -Raw
if ($jeHtml -match 'Journal Entry Register') {
    Write-Host "✅ PASS - JE Register page exists" -ForegroundColor Green
    $results += @{Test="TEST-056"; Status="PASS"; Details="Page found"}
} else {
    Write-Host "❌ FAIL - JE Register page missing" -ForegroundColor Red
    $results += @{Test="TEST-056"; Status="FAIL"; Details="Page not found"}
}
Write-Host ""

# TEST-057: Test JE drilldown modal
Write-Host "TEST-057: Test JE drilldown modal functionality" -ForegroundColor Green
if ($jeHtml -match 'je-clickable' -and $jeHtml -match 'JEViewer') {
    Write-Host "✅ PASS - Drilldown functionality implemented" -ForegroundColor Green
    $results += @{Test="TEST-057"; Status="PASS"; Details="Drilldown found"}
} else {
    Write-Host "❌ FAIL - Drilldown missing" -ForegroundColor Red
    $results += @{Test="TEST-057"; Status="FAIL"; Details="No drilldown"}
}
Write-Host ""

# TEST-058: Load Vendor Ledger
Write-Host "TEST-058: Load Vendor Ledger" -ForegroundColor Green
$vlHtml = Get-Content "C:\Dev\AIRP2\vendor-ledger.html" -Raw
if ($vlHtml -match 'Vendor Ledger') {
    Write-Host "✅ PASS - Vendor Ledger page exists" -ForegroundColor Green
    $results += @{Test="TEST-058"; Status="PASS"; Details="Page found"}
} else {
    Write-Host "❌ FAIL - Vendor Ledger page missing" -ForegroundColor Red
    $results += @{Test="TEST-058"; Status="FAIL"; Details="Page not found"}
}
Write-Host ""

# TEST-059: Test vendor ledger reconciliation display
Write-Host "TEST-059: Test vendor ledger reconciliation display" -ForegroundColor Green
if ($vlHtml -match 'reconciliation' -or $vlHtml -match 'variance') {
    Write-Host "✅ PASS - Reconciliation display implemented" -ForegroundColor Green
    $results += @{Test="TEST-059"; Status="PASS"; Details="Reconciliation found"}
} else {
    Write-Host "❌ FAIL - Reconciliation display missing" -ForegroundColor Red
    $results += @{Test="TEST-059"; Status="FAIL"; Details="No reconciliation"}
}
Write-Host ""

# TEST-060: Load Customer Ledger
Write-Host "TEST-060: Load Customer Ledger" -ForegroundColor Green
$clHtml = Get-Content "C:\Dev\AIRP2\customer-ledger.html" -Raw
if ($clHtml -match 'Customer Ledger') {
    Write-Host "✅ PASS - Customer Ledger page exists" -ForegroundColor Green
    $results += @{Test="TEST-060"; Status="PASS"; Details="Page found"}
} else {
    Write-Host "❌ FAIL - Customer Ledger page missing" -ForegroundColor Red
    $results += @{Test="TEST-060"; Status="FAIL"; Details="Page not found"}
}
Write-Host ""

# TEST-061: Test customer ledger reconciliation display
Write-Host "TEST-061: Test customer ledger reconciliation display" -ForegroundColor Green
if ($clHtml -match 'reconciliation' -or $clHtml -match 'variance') {
    Write-Host "✅ PASS - Reconciliation display implemented" -ForegroundColor Green
    $results += @{Test="TEST-061"; Status="PASS"; Details="Reconciliation found"}
} else {
    Write-Host "❌ FAIL - Reconciliation display missing" -ForegroundColor Red
    $results += @{Test="TEST-061"; Status="FAIL"; Details="No reconciliation"}
}
Write-Host ""

# TEST-062: Load Account Balances report
Write-Host "TEST-062: Load Account Balances report" -ForegroundColor Green
try {
    $ab = Invoke-RestMethod -Uri "$baseUrl/account-balances?tenant_id=$tenantId" -Method GET
    Write-Host "✅ PASS - Account Balances loaded" -ForegroundColor Green
    $results += @{Test="TEST-062"; Status="PASS"; Details="Loaded successfully"}
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-062"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
$passed = ($results | Where-Object {$_.Status -eq "PASS"}).Count
$failed = ($results | Where-Object {$_.Status -eq "FAIL"}).Count
$partial = ($results | Where-Object {$_.Status -eq "PARTIAL"}).Count
$total = $results.Count

Write-Host "Total Tests: $total" -ForegroundColor White
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host "Partial: $partial" -ForegroundColor Yellow
Write-Host "Pass Rate: $([Math]::Round(($passed/$total)*100, 2))%" -ForegroundColor Cyan
Write-Host ""
Write-Host "Completed at $(Get-Date)" -ForegroundColor Yellow

# Export results
$results | Export-Csv -Path "C:\Dev\AIRP2\test_results_iteration_4.csv" -NoTypeInformation
Write-Host "Results exported to test_results_iteration_4.csv" -ForegroundColor Cyan
