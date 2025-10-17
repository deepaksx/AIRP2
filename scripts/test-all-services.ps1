# AIRP v2.0 - Comprehensive Service Testing Script

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "AIRP v2.0 - Service Testing Suite" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$TenantId = "00000000-0000-0000-0000-000000000001"
$TestsPassed = 0
$TestsFailed = 0

function Test-Service {
    param(
        [string]$ServiceName,
        [string]$URL
    )

    Write-Host "Testing $ServiceName..." -NoNewline

    try {
        $response = Invoke-WebRequest -Uri $URL -Method GET -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host " OK" -ForegroundColor Green
            $script:TestsPassed++
            return $true
        }
    } catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "   Error: $_" -ForegroundColor Gray
        $script:TestsFailed++
        return $false
    }
}

Write-Host "=============================================" -ForegroundColor Yellow
Write-Host "INFRASTRUCTURE HEALTH CHECKS" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow

Test-Service "PostgreSQL" "http://localhost:5432" # This will fail, but that's ok
Test-Service "Kafka Console" "http://localhost:8080"
Test-Service "Redis" "http://localhost:6379" # This will fail, but that's ok
Test-Service "Qdrant" "http://localhost:6333"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Yellow
Write-Host "CORE SERVICES HEALTH CHECKS" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow

Test-Service "Ledger Writer" "http://localhost:3001/health"
Test-Service "Projection Service" "http://localhost:3002/health"
Test-Service "AP Service" "http://localhost:3003/health"
Test-Service "AR Service" "http://localhost:3004/health"
Test-Service "Treasury Service" "http://localhost:3005/health"
Test-Service "FPnA Service" "http://localhost:3006/health"
Test-Service "Policy Engine" "http://localhost:3007/health"
Test-Service "Reporting Service" "http://localhost:3008/health"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Yellow
Write-Host "AI SERVICES HEALTH CHECKS" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow

Test-Service "AI Auto-Accounting" "http://localhost:8001/health"
Test-Service "AI Reconciliation" "http://localhost:8002/health"
Test-Service "AI Forecasting" "http://localhost:8003/health"
Test-Service "AI Narrative" "http://localhost:8004/health"
Test-Service "AI Policy Advisor" "http://localhost:8005/health"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Yellow
Write-Host "FUNCTIONAL TESTS" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow

# Test AI Auto-Accounting
Write-Host "Testing AI Classification..." -NoNewline
try {
    $body = @{
        tenant_id = $TenantId
        invoice_id = "test-001"
        transaction_type = "AP"
        lines = @(
            @{
                line_number = 1
                description = "Office supplies - printer paper and pens"
                amount = 150.00
                quantity = 1
            }
        )
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "http://localhost:8001/classify" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10

    if ($response.suggestions) {
        Write-Host " OK" -ForegroundColor Green
        Write-Host "   Suggested Account: $($response.suggestions[0].account_code) - $($response.suggestions[0].account_name)" -ForegroundColor Gray
        $script:TestsPassed++
    }
} catch {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Gray
    $script:TestsFailed++
}

# Test AI Policy Advisor
Write-Host "Testing AI Policy Advisor..." -NoNewline
try {
    $body = @{
        tenant_id = $TenantId
        query = "When should revenue be recognized for a service contract?"
        context_type = "ifrs"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "http://localhost:8005/query" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10

    if ($response.answer) {
        Write-Host " OK" -ForegroundColor Green
        Write-Host "   Confidence: $([math]::Round($response.confidence_score * 100, 1))%" -ForegroundColor Gray
        $script:TestsPassed++
    }
} catch {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Gray
    $script:TestsFailed++
}

# Test Reporting Service
Write-Host "Testing Reporting Service (Trial Balance)..." -NoNewline
try {
    $url = "http://localhost:3008/reports/trial-balance?tenant_id=$TenantId" + "&period_end_date=2025-01-31"
    $response = Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 10

    Write-Host " OK" -ForegroundColor Green
    $script:TestsPassed++
} catch {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Gray
    $script:TestsFailed++
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Tests Passed: $TestsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($TestsFailed -eq 0) {
    Write-Host "SUCCESS: ALL TESTS PASSED!" -ForegroundColor Green
} else {
    Write-Host "WARNING: Some tests failed. Check the output above." -ForegroundColor Yellow
}
Write-Host ""
