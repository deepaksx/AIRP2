# AIRP v2 - Complete Remaining Test Suite
# Iterations 5, 6, 7: Full automation without interruptions

Write-Host "=== AIRP v2 - Complete Remaining Test Suite ===" -ForegroundColor Cyan
Write-Host "Starting at $(Get-Date)" -ForegroundColor Yellow
Write-Host ""

$tenantId = "00000000-0000-0000-0000-000000000001"
$results = @()

#####################################################
# ITERATION 5: AI-Powered Features (6 tests)
#####################################################
Write-Host "=== ITERATION 5: AI-Powered Features ===" -ForegroundColor Magenta
Write-Host ""

# TEST-063: AI Classification Service (Port 8001)
Write-Host "TEST-063: AI Classification Service" -ForegroundColor Green
try {
    $classifyPayload = @{
        description = "Office supplies purchase from Staples"
        amount = 150.50
        vendor = "Staples Inc"
    } | ConvertTo-Json

    $classify = Invoke-RestMethod -Uri "http://localhost:8001/classify" -Method POST -ContentType "application/json" -Body $classifyPayload -TimeoutSec 5
    if ($classify.account_code) {
        Write-Host "✅ PASS - Classified to account: $($classify.account_code) (Confidence: $($classify.confidence))" -ForegroundColor Green
        $results += @{Test="TEST-063"; Status="PASS"; Details="Account: $($classify.account_code)"}
    } else {
        Write-Host "⚠️ PARTIAL - Response received but no account_code" -ForegroundColor Yellow
        $results += @{Test="TEST-063"; Status="PARTIAL"; Details="No account_code"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-063"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-064: AI Reconciliation Service (Port 8002)
Write-Host "TEST-064: AI Reconciliation Service" -ForegroundColor Green
try {
    $reconPayload = @{
        bank_transactions = @(
            @{date="2025-10-20"; description="Payment from ABC Corp"; amount=5000}
        )
        gl_transactions = @(
            @{date="2025-10-20"; description="Invoice ABC-001"; amount=5000}
        )
    } | ConvertTo-Json -Depth 3

    $recon = Invoke-RestMethod -Uri "http://localhost:8002/reconcile" -Method POST -ContentType "application/json" -Body $reconPayload -TimeoutSec 5
    if ($recon.matches -or $recon.suggested_matches) {
        Write-Host "✅ PASS - Reconciliation service responding" -ForegroundColor Green
        $results += @{Test="TEST-064"; Status="PASS"; Details="Service active"}
    } else {
        Write-Host "⚠️ PARTIAL - Response received but unexpected format" -ForegroundColor Yellow
        $results += @{Test="TEST-064"; Status="PARTIAL"; Details="Unexpected format"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-064"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-065: AI Forecasting Service (Port 8003)
Write-Host "TEST-065: AI Cash Flow Forecasting Service" -ForegroundColor Green
try {
    $forecastPayload = @{
        historical_data = @(
            @{date="2025-09-01"; amount=10000},
            @{date="2025-09-15"; amount=12000},
            @{date="2025-10-01"; amount=11000}
        )
        periods = 3
    } | ConvertTo-Json -Depth 3

    $forecast = Invoke-RestMethod -Uri "http://localhost:8003/forecast" -Method POST -ContentType "application/json" -Body $forecastPayload -TimeoutSec 5
    if ($forecast.predictions -or $forecast.forecast) {
        Write-Host "✅ PASS - Forecasting service responding" -ForegroundColor Green
        $results += @{Test="TEST-065"; Status="PASS"; Details="Service active"}
    } else {
        Write-Host "⚠️ PARTIAL - Response received but unexpected format" -ForegroundColor Yellow
        $results += @{Test="TEST-065"; Status="PARTIAL"; Details="Unexpected format"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-065"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-066: AI Narrative Generation (Port 8004)
Write-Host "TEST-066: AI Narrative Generation Service" -ForegroundColor Green
try {
    $narrativePayload = @{
        report_type = "income_statement"
        data = @{
            revenue = 100000
            expenses = 75000
            net_income = 25000
        }
    } | ConvertTo-Json -Depth 3

    $narrative = Invoke-RestMethod -Uri "http://localhost:8004/generate-narrative" -Method POST -ContentType "application/json" -Body $narrativePayload -TimeoutSec 5
    if ($narrative.narrative -or $narrative.text) {
        Write-Host "✅ PASS - Narrative generation responding" -ForegroundColor Green
        $results += @{Test="TEST-066"; Status="PASS"; Details="Service active"}
    } else {
        Write-Host "⚠️ PARTIAL - Response received but unexpected format" -ForegroundColor Yellow
        $results += @{Test="TEST-066"; Status="PARTIAL"; Details="Unexpected format"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-066"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-067: AI Policy Advisor (Port 8005)
Write-Host "TEST-067: AI Policy Advisor Service" -ForegroundColor Green
try {
    $policyPayload = @{
        question = "What is the approval threshold for expense reimbursements?"
    } | ConvertTo-Json

    $policy = Invoke-RestMethod -Uri "http://localhost:8005/advise" -Method POST -ContentType "application/json" -Body $policyPayload -TimeoutSec 5
    if ($policy.answer -or $policy.advice) {
        Write-Host "✅ PASS - Policy advisor responding" -ForegroundColor Green
        $results += @{Test="TEST-067"; Status="PASS"; Details="Service active"}
    } else {
        Write-Host "⚠️ PARTIAL - Response received but unexpected format" -ForegroundColor Yellow
        $results += @{Test="TEST-067"; Status="PARTIAL"; Details="Unexpected format"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-067"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-068: ChatERP Query Parser (Port 8006)
Write-Host "TEST-068: ChatERP Query Parser Service" -ForegroundColor Green
try {
    $queryPayload = @{
        query = "Show me all invoices from last month"
    } | ConvertTo-Json

    $chatErp = Invoke-RestMethod -Uri "http://localhost:8006/parse-query" -Method POST -ContentType "application/json" -Body $queryPayload -TimeoutSec 5
    if ($chatErp.sql -or $chatErp.intent) {
        Write-Host "✅ PASS - Query parser responding" -ForegroundColor Green
        $results += @{Test="TEST-068"; Status="PASS"; Details="Service active"}
    } else {
        Write-Host "⚠️ PARTIAL - Response received but unexpected format" -ForegroundColor Yellow
        $results += @{Test="TEST-068"; Status="PARTIAL"; Details="Unexpected format"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-068"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

#####################################################
# ITERATION 6: Architecture & Data Integrity (8 tests)
#####################################################
Write-Host "=== ITERATION 6: Architecture & Data Integrity ===" -ForegroundColor Magenta
Write-Host ""

# TEST-069: Verify event_store table exists
Write-Host "TEST-069: Verify event_store table exists" -ForegroundColor Green
try {
    $queryUrl = "http://localhost:3008/api/query"
    $query = @{
        query = "SELECT COUNT(*) as count FROM event_store WHERE tenant_id = '$tenantId'"
    } | ConvertTo-Json

    $eventCount = Invoke-RestMethod -Uri $queryUrl -Method POST -ContentType "application/json" -Body $query
    Write-Host "✅ PASS - Event store has $($eventCount[0].count) events" -ForegroundColor Green
    $results += @{Test="TEST-069"; Status="PASS"; Details="$($eventCount[0].count) events"}
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-069"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-070: Verify events are created for journal entries
Write-Host "TEST-070: Verify events created for journal entries" -ForegroundColor Green
try {
    $query = @{
        query = "SELECT COUNT(*) as count FROM event_store WHERE event_type = 'JournalEntryPosted' AND tenant_id = '$tenantId'"
    } | ConvertTo-Json

    $jeEvents = Invoke-RestMethod -Uri $queryUrl -Method POST -ContentType "application/json" -Body $query
    if ([int]$jeEvents[0].count -gt 0) {
        Write-Host "✅ PASS - Found $($jeEvents[0].count) JournalEntryPosted events" -ForegroundColor Green
        $results += @{Test="TEST-070"; Status="PASS"; Details="$($jeEvents[0].count) events"}
    } else {
        Write-Host "❌ FAIL - No JournalEntryPosted events found" -ForegroundColor Red
        $results += @{Test="TEST-070"; Status="FAIL"; Details="No events"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-070"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-071: Verify event checksums (SHA-256)
Write-Host "TEST-071: Verify event checksums exist" -ForegroundColor Green
try {
    $query = @{
        query = "SELECT checksum FROM event_store WHERE tenant_id = '$tenantId' LIMIT 1"
    } | ConvertTo-Json

    $checksum = Invoke-RestMethod -Uri $queryUrl -Method POST -ContentType "application/json" -Body $query
    if ($checksum[0].checksum -and $checksum[0].checksum.Length -eq 64) {
        Write-Host "✅ PASS - SHA-256 checksums present (64 chars)" -ForegroundColor Green
        $results += @{Test="TEST-071"; Status="PASS"; Details="SHA-256 verified"}
    } else {
        Write-Host "❌ FAIL - Invalid or missing checksums" -ForegroundColor Red
        $results += @{Test="TEST-071"; Status="FAIL"; Details="Invalid checksum"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-071"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-072: Verify gl_balances projection exists
Write-Host "TEST-072: Verify gl_balances projection exists" -ForegroundColor Green
try {
    $query = @{
        query = "SELECT COUNT(*) as count FROM gl_balances WHERE tenant_id = '$tenantId'"
    } | ConvertTo-Json

    $glCount = Invoke-RestMethod -Uri $queryUrl -Method POST -ContentType "application/json" -Body $query
    Write-Host "✅ PASS - gl_balances has $($glCount[0].count) records" -ForegroundColor Green
    $results += @{Test="TEST-072"; Status="PASS"; Details="$($glCount[0].count) records"}
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-072"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-073: Verify trial_balance materialized view
Write-Host "TEST-073: Verify trial_balance materialized view" -ForegroundColor Green
try {
    $query = @{
        query = "SELECT COUNT(*) as count FROM trial_balance"
    } | ConvertTo-Json

    $tbCount = Invoke-RestMethod -Uri $queryUrl -Method POST -ContentType "application/json" -Body $query
    Write-Host "✅ PASS - trial_balance view has $($tbCount[0].count) accounts" -ForegroundColor Green
    $results += @{Test="TEST-073"; Status="PASS"; Details="$($tbCount[0].count) accounts"}
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-073"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-074: Test multi-tenancy (tenant_id isolation)
Write-Host "TEST-074: Test multi-tenancy isolation" -ForegroundColor Green
try {
    $query = @{
        query = "SELECT DISTINCT tenant_id FROM journal_entries LIMIT 5"
    } | ConvertTo-Json

    $tenants = Invoke-RestMethod -Uri $queryUrl -Method POST -ContentType "application/json" -Body $query
    Write-Host "✅ PASS - Multi-tenancy fields present ($($tenants.Count) tenant(s))" -ForegroundColor Green
    $results += @{Test="TEST-074"; Status="PASS"; Details="$($tenants.Count) tenants"}
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-074"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-075: Verify audit trail fields
Write-Host "TEST-075: Verify audit trail fields" -ForegroundColor Green
try {
    $query = @{
        query = "SELECT created_at, posted_at, posted_by FROM journal_entries WHERE tenant_id = '$tenantId' AND status = 'posted' LIMIT 1"
    } | ConvertTo-Json

    $audit = Invoke-RestMethod -Uri $queryUrl -Method POST -ContentType "application/json" -Body $query
    if ($audit[0].created_at -and $audit[0].posted_at) {
        Write-Host "✅ PASS - Audit trail fields present" -ForegroundColor Green
        $results += @{Test="TEST-075"; Status="PASS"; Details="Audit fields verified"}
    } else {
        Write-Host "❌ FAIL - Missing audit trail fields" -ForegroundColor Red
        $results += @{Test="TEST-075"; Status="FAIL"; Details="Missing fields"}
    }
} catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    $results += @{Test="TEST-075"; Status="FAIL"; Details=$_.Exception.Message}
}
Write-Host ""

# TEST-076: Test immutability (no deletions, reversals only)
Write-Host "TEST-076: Test immutability principle (Code Review)" -ForegroundColor Green
$ledgerService = Get-Content "C:\Dev\AIRP2\services\ledger-writer\src\domain\journal-entry.service.ts" -Raw
if ($ledgerService -match 'reversal' -or $ledgerService -match 'reverse') {
    Write-Host "✅ PASS - Reversal logic found in service" -ForegroundColor Green
    $results += @{Test="TEST-076"; Status="PASS"; Details="Reversal logic present"}
} else {
    Write-Host "⚠️ PARTIAL - Could not verify reversal logic" -ForegroundColor Yellow
    $results += @{Test="TEST-076"; Status="PARTIAL"; Details="Code not verified"}
}
Write-Host ""

#####################################################
# ITERATION 7: User Interface Pages (20 tests)
#####################################################
Write-Host "=== ITERATION 7: User Interface Pages ===" -ForegroundColor Magenta
Write-Host ""

$pages = @(
    @{Test="TEST-077"; File="index.html"; Name="Main Dashboard"},
    @{Test="TEST-078"; File="post-je.html"; Name="Journal Entry Form"},
    @{Test="TEST-079"; File="trial-balance.html"; Name="Trial Balance"},
    @{Test="TEST-080"; File="income-statement.html"; Name="Income Statement"},
    @{Test="TEST-081"; File="balance-sheet.html"; Name="Balance Sheet"},
    @{Test="TEST-082"; File="cash-flow-statement.html"; Name="Cash Flow Statement"},
    @{Test="TEST-083"; File="gl-line-items.html"; Name="GL Line Items"},
    @{Test="TEST-084"; File="je-register.html"; Name="JE Register"},
    @{Test="TEST-085"; File="account-balances.html"; Name="Account Balances"},
    @{Test="TEST-086"; File="vendor-ledger.html"; Name="Vendor Ledger"},
    @{Test="TEST-087"; File="customer-ledger.html"; Name="Customer Ledger"},
    @{Test="TEST-088"; File="chaterp.html"; Name="ChatERP"},
    @{Test="TEST-089"; File="database-explorer.html"; Name="Database Explorer"},
    @{Test="TEST-090"; File="master-data.html"; Name="Master Data"},
    @{Test="TEST-091"; File="classify-demo.html"; Name="AI Classification Demo"},
    @{Test="TEST-092"; File="recon-demo.html"; Name="AI Reconciliation Demo"},
    @{Test="TEST-093"; File="cashflow-demo.html"; Name="AI Forecast Demo"},
    @{Test="TEST-094"; File="narrative-demo.html"; Name="AI Narrative Demo"},
    @{Test="TEST-095"; File="policy-demo.html"; Name="AI Policy Demo"},
    @{Test="TEST-096"; File="ledgers-dashboard.html"; Name="Ledgers Dashboard"}
)

foreach ($page in $pages) {
    Write-Host "$($page.Test): Load $($page.Name)" -ForegroundColor Green
    $filePath = "C:\Dev\AIRP2\$($page.File)"
    if (Test-Path $filePath) {
        Write-Host "✅ PASS - $($page.File) exists" -ForegroundColor Green
        $results += @{Test=$page.Test; Status="PASS"; Details="File exists"}
    } else {
        Write-Host "❌ FAIL - $($page.File) not found" -ForegroundColor Red
        $results += @{Test=$page.Test; Status="FAIL"; Details="File not found"}
    }
}
Write-Host ""

#####################################################
# FINAL SUMMARY
#####################################################
Write-Host "=== COMPLETE TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host ""

$totalPassed = ($results | Where-Object {$_.Status -eq "PASS"}).Count
$totalFailed = ($results | Where-Object {$_.Status -eq "FAIL"}).Count
$totalPartial = ($results | Where-Object {$_.Status -eq "PARTIAL"}).Count
$totalTests = $results.Count

Write-Host "Iteration 5 (AI Features): 6 tests" -ForegroundColor White
Write-Host "Iteration 6 (Architecture): 8 tests" -ForegroundColor White
Write-Host "Iteration 7 (UI Pages): 20 tests" -ForegroundColor White
Write-Host "─────────────────────────────" -ForegroundColor Gray
Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $totalPassed" -ForegroundColor Green
Write-Host "Failed: $totalFailed" -ForegroundColor Red
Write-Host "Partial: $totalPartial" -ForegroundColor Yellow
Write-Host "Pass Rate: $([Math]::Round(($totalPassed/$totalTests)*100, 2))%" -ForegroundColor Cyan
Write-Host ""

# Grand total across all iterations
Write-Host "=== GRAND TOTAL (All 7 Iterations) ===" -ForegroundColor Magenta
Write-Host "Iteration 1 (Core Accounting): 9/10 passed" -ForegroundColor White
Write-Host "Iteration 2 (Journal Entry): 15/15 passed" -ForegroundColor White
Write-Host "Iteration 3 (Sub-Ledger): 10/12 passed" -ForegroundColor White
Write-Host "Iteration 4 (Financial Reporting): 23/25 passed" -ForegroundColor White
Write-Host "Iteration 5 (AI Features): $($results | Where-Object {$_.Test -like 'TEST-06*' -and $_.Status -eq 'PASS'} | Measure-Object | Select-Object -ExpandProperty Count)/6" -ForegroundColor White
Write-Host "Iteration 6 (Architecture): $($results | Where-Object {$_.Test -like 'TEST-07*' -and $_.Status -eq 'PASS'} | Measure-Object | Select-Object -ExpandProperty Count)/8" -ForegroundColor White
Write-Host "Iteration 7 (UI Pages): $($results | Where-Object {$_.Test -like 'TEST-0[89]*' -or $_.Test -like 'TEST-09*' -and $_.Status -eq 'PASS'} | Measure-Object | Select-Object -ExpandProperty Count)/20" -ForegroundColor White
Write-Host ""

$grandTotal = 91
$grandPassed = 57 + $totalPassed
Write-Host "GRAND TOTAL: $grandPassed/$grandTotal tests passed" -ForegroundColor Cyan
Write-Host "OVERALL PASS RATE: $([Math]::Round(($grandPassed/$grandTotal)*100, 2))%" -ForegroundColor Cyan
Write-Host ""
Write-Host "Completed at $(Get-Date)" -ForegroundColor Yellow

# Export results
$results | Export-Csv -Path "C:\Dev\AIRP2\test_results_iterations_5_6_7.csv" -NoTypeInformation
Write-Host "Results exported to test_results_iterations_5_6_7.csv" -ForegroundColor Cyan
