#!/usr/bin/env pwsh
# AIRP v2.11.0 - End-to-End Context Feature Test
# Tests the complete AI context generation and semantic search flow

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "AIRP v2.11.0 - AI Context Feature E2E Test" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$TENANT_ID = "00000000-0000-0000-0000-000000000001"
$CONTEXT_API = "http://localhost:8007"
$REPORTING_API = "http://localhost:3008"

$testsPassed = 0
$testsFailed = 0

# Test function
function Test-Step {
    param (
        [string]$Name,
        [scriptblock]$Test
    )

    Write-Host "TEST: $Name" -ForegroundColor Yellow
    try {
        $result = & $Test
        if ($result) {
            Write-Host "  ✅ PASS" -ForegroundColor Green
            $script:testsPassed++
        } else {
            Write-Host "  ❌ FAIL" -ForegroundColor Red
            $script:testsFailed++
        }
    } catch {
        Write-Host "  ❌ FAIL: $_" -ForegroundColor Red
        $script:testsFailed++
    }
    Write-Host ""
}

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Phase 1: Service Health Checks" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Test-Step "PostgreSQL is running" {
    $status = docker ps --filter "name=airp-postgres" --filter "status=running" --format "{{.Names}}"
    return $status -eq "airp-postgres"
}

Test-Step "AI Context Generator is running" {
    $status = docker ps --filter "name=airp-ai-context-generator" --filter "status=running" --format "{{.Names}}"
    return $status -eq "airp-ai-context-generator"
}

Test-Step "AI Context Generator is healthy" {
    $health = Invoke-RestMethod -Uri "$CONTEXT_API/health" -Method Get -TimeoutSec 5
    return ($health.status -eq "healthy" -and $health.ai_enabled -eq $true)
}

Test-Step "Reporting Service is running" {
    $status = docker ps --filter "name=airp-reporting-service" --filter "status=running" --format "{{.Names}}"
    return $status -match "reporting"
}

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Phase 2: Database Migration Verification" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Test-Step "AI context columns exist in vendors table" {
    $query = "SELECT column_name FROM information_schema.columns WHERE table_name = 'vendors' AND column_name LIKE 'ai_context%';"
    $result = docker exec -i airp-postgres psql -U airp_admin -d airp_master -t -c $query
    return $result -match "ai_context_summary"
}

Test-Step "AI context columns exist in chart_of_accounts table" {
    $query = "SELECT column_name FROM information_schema.columns WHERE table_name = 'chart_of_accounts' AND column_name LIKE 'ai_context%';"
    $result = docker exec -i airp-postgres psql -U airp_admin -d airp_master -t -c $query
    return $result -match "ai_context_summary"
}

Test-Step "GIN indexes are created for keyword search" {
    $query = "SELECT indexname FROM pg_indexes WHERE indexname LIKE '%context_keywords%';"
    $result = docker exec -i airp-postgres psql -U airp_admin -d airp_master -t -c $query
    return $result -match "idx_vendors_context_keywords"
}

Test-Step "ai_context_coverage view exists" {
    $query = "SELECT viewname FROM pg_views WHERE viewname = 'ai_context_coverage';"
    $result = docker exec -i airp-postgres psql -U airp_admin -d airp_master -t -c $query
    return $result -match "ai_context_coverage"
}

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Phase 3: Context Generation Tests" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Create a test vendor
$testVendorId = $null

Test-Step "Create test vendor in database" {
    $query = @"
INSERT INTO vendors (vendor_id, tenant_id, vendor_code, vendor_name, payment_terms, contact_email, status)
VALUES (uuid_generate_v4(), '$TENANT_ID', 'TEST-V001', 'Test Office Supplies LLC', 30, 'test@office.ae', 'active')
RETURNING vendor_id;
"@
    $result = docker exec -i airp-postgres psql -U airp_admin -d airp_master -t -c $query
    $script:testVendorId = $result.Trim()
    return $script:testVendorId -ne ""
}

Test-Step "Generate AI context for test vendor" {
    $body = @{
        entity_type = "vendor"
        entity_id = $script:testVendorId
        tenant_id = $TENANT_ID
        entity_data = @{
            vendor_code = "TEST-V001"
            vendor_name = "Test Office Supplies LLC"
            payment_terms = 30
            contact_email = "test@office.ae"
        }
    } | ConvertTo-Json

    $response = Invoke-RestMethod `
        -Uri "$CONTEXT_API/generate-context" `
        -Method Post `
        -Body $body `
        -ContentType "application/json" `
        -TimeoutSec 30

    return ($response.ai_context_summary -ne $null -and $response.ai_context_keywords.Count -gt 0)
}

Test-Step "Verify context was saved to database" {
    $query = "SELECT ai_context_summary FROM vendors WHERE vendor_id = '$($script:testVendorId)';"
    $result = docker exec -i airp-postgres psql -U airp_admin -d airp_master -t -c $query
    return $result -match "office"
}

Test-Step "Verify context keywords are searchable" {
    $query = "SELECT COUNT(*) FROM vendors WHERE ai_context_keywords && ARRAY['office', 'supplies'] AND vendor_id = '$($script:testVendorId)';"
    $result = docker exec -i airp-postgres psql -U airp_admin -d airp_master -t -c $query
    return $result.Trim() -eq "1"
}

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Phase 4: Semantic Search Tests" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Test-Step "Search vendors by context keywords (office supplies)" {
    $query = @"
SELECT vendor_name FROM vendors
WHERE tenant_id = '$TENANT_ID'
  AND ai_context_keywords && ARRAY['office', 'supplies']
LIMIT 5;
"@
    $result = docker exec -i airp-postgres psql -U airp_admin -d airp_master -t -c $query
    return $result -match "Office"
}

Test-Step "Full-text search on vendor context summary" {
    $query = @"
SELECT vendor_name FROM vendors
WHERE tenant_id = '$TENANT_ID'
  AND to_tsvector('english', COALESCE(ai_context_summary, '')) @@ plainto_tsquery('english', 'office supplies')
LIMIT 5;
"@
    $result = docker exec -i airp-postgres psql -U airp_admin -d airp_master -t -c $query
    return $result -match "Office"
}

Test-Step "Query with Reporting API includes context" {
    $query = "SELECT vendor_name, ai_context_summary FROM vendors WHERE tenant_id = '$TENANT_ID' AND ai_context_summary IS NOT NULL LIMIT 3;"

    $body = @{
        query = $query
        params = @()
    } | ConvertTo-Json

    $response = Invoke-RestMethod `
        -Uri "$REPORTING_API/api/query" `
        -Method Post `
        -Body $body `
        -ContentType "application/json" `
        -TimeoutSec 10

    return ($response.Count -gt 0 -and $response[0].ai_context_summary -ne $null)
}

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Phase 5: Coverage Statistics" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Test-Step "Get context coverage statistics" {
    $stats = Invoke-RestMethod -Uri "$CONTEXT_API/context-stats?tenant_id=$TENANT_ID" -Method Get
    Write-Host "  Total Records: $($stats.total_records)" -ForegroundColor Gray
    Write-Host "  With Context: $($stats.records_with_context)" -ForegroundColor Gray
    Write-Host "  Coverage: $($stats.coverage_percentage)%" -ForegroundColor $(if ($stats.coverage_percentage -ge 50) { "Green" } else { "Yellow" })
    return $stats.total_records -gt 0
}

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Phase 6: Cleanup" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Test-Step "Delete test vendor" {
    $query = "DELETE FROM vendors WHERE vendor_id = '$($script:testVendorId)';"
    docker exec -i airp-postgres psql -U airp_admin -d airp_master -c $query | Out-Null
    return $true
}

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Test Results" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tests Passed: " -NoNewline -ForegroundColor White
Write-Host "$testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: " -NoNewline -ForegroundColor White
Write-Host "$testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "🎉 All tests passed! AI Context feature is working correctly." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Generate context for all existing data: .\run_generate_contexts.ps1" -ForegroundColor White
    Write-Host "  2. Test in ChatERP: http://localhost:5000/chaterp.html" -ForegroundColor White
    Write-Host "  3. Try queries like 'Who sells office supplies?'" -ForegroundColor White
    exit 0
} else {
    Write-Host "❌ Some tests failed. Please check the errors above." -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check logs: docker logs airp-ai-context-generator" -ForegroundColor White
    Write-Host "  2. Verify API key: docker exec airp-ai-context-generator env | grep ANTHROPIC" -ForegroundColor White
    Write-Host "  3. Run migration: .\run_context_migration.ps1" -ForegroundColor White
    exit 1
}
