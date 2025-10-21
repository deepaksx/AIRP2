#!/usr/bin/env pwsh
# AIRP v2.11.0 - Generate AI Context for Existing Data
# Batch generates intelligent context metadata for all records

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "AIRP v2.11.0 - AI Context Generator" -ForegroundColor Cyan
Write-Host "Generating intelligent context for existing data" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$TENANT_ID = "00000000-0000-0000-0000-000000000001"
$CONTEXT_API = "http://localhost:8007"

# Check if AI Context Generator is running
Write-Host "[1/5] Checking AI Context Generator service..." -ForegroundColor Yellow
$serviceStatus = docker ps --filter "name=airp-ai-context-generator" --filter "status=running" --format "{{.Names}}"

if ($serviceStatus -ne "airp-ai-context-generator") {
    Write-Host "❌ AI Context Generator is not running!" -ForegroundColor Red
    Write-Host "   Start it with: docker compose up -d ai-context-generator" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ AI Context Generator is running" -ForegroundColor Green
Write-Host ""

# Test API connectivity
Write-Host "[2/5] Testing API connectivity..." -ForegroundColor Yellow
try {
    $healthCheck = Invoke-RestMethod -Uri "$CONTEXT_API/health" -Method Get -TimeoutSec 5
    Write-Host "✅ API is healthy: $($healthCheck.service)" -ForegroundColor Green

    if (-not $healthCheck.ai_enabled) {
        Write-Host "⚠️  WARNING: AI is not enabled (missing ANTHROPIC_API_KEY)" -ForegroundColor Yellow
        Write-Host "   Set environment variable: `$env:ANTHROPIC_API_KEY=<your-key>" -ForegroundColor Yellow
        Write-Host "   Then restart: docker compose restart ai-context-generator" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ Failed to connect to API: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Function to generate context for entity type
function Generate-ContextFor {
    param (
        [string]$EntityType,
        [int]$Limit = 100
    )

    Write-Host "   Processing $EntityType records..." -ForegroundColor Gray

    try {
        $body = @{
            entity_type = $EntityType
            tenant_id = $TENANT_ID
            limit = $Limit
        } | ConvertTo-Json

        $response = Invoke-RestMethod `
            -Uri "$CONTEXT_API/batch-generate" `
            -Method Post `
            -Body $body `
            -ContentType "application/json" `
            -TimeoutSec 300

        Write-Host "      ✅ $($response.successful)/$($response.total_processed) successful" -ForegroundColor Green
        Write-Host "      📊 Coverage: $($response.coverage_percentage)%" -ForegroundColor Cyan

        if ($response.failed -gt 0) {
            Write-Host "      ⚠️  $($response.failed) failed" -ForegroundColor Yellow
        }

        return $true
    } catch {
        Write-Host "      ❌ Error: $_" -ForegroundColor Red
        return $false
    }
}

# Generate context for all entity types
Write-Host "[3/5] Generating context for GL Accounts..." -ForegroundColor Yellow
Generate-ContextFor -EntityType "account" -Limit 100
Write-Host ""

Write-Host "[4/5] Generating context for Vendors..." -ForegroundColor Yellow
Generate-ContextFor -EntityType "vendor" -Limit 100
Write-Host ""

Write-Host "[5/5] Generating context for Customers..." -ForegroundColor Yellow
Generate-ContextFor -EntityType "customer" -Limit 100
Write-Host ""

# Optional: Generate context for transactions (can be slow)
Write-Host "Would you like to generate context for journal entries? (This may take several minutes)" -ForegroundColor Yellow
$generateJE = Read-Host "Generate journal entry context? (y/N)"

if ($generateJE -eq "y" -or $generateJE -eq "Y") {
    Write-Host ""
    Write-Host "[BONUS] Generating context for Journal Entries..." -ForegroundColor Yellow
    Generate-ContextFor -EntityType "journal_entry" -Limit 50
    Write-Host ""
}

# Show coverage statistics
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Fetching Coverage Statistics..." -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

try {
    $stats = Invoke-RestMethod -Uri "$CONTEXT_API/context-stats?tenant_id=$TENANT_ID" -Method Get

    Write-Host "Overall Coverage:" -ForegroundColor Cyan
    Write-Host "  Total Records: $($stats.total_records)" -ForegroundColor White
    Write-Host "  With Context: $($stats.records_with_context)" -ForegroundColor White
    Write-Host "  Coverage: $($stats.coverage_percentage)%" -ForegroundColor $(if ($stats.coverage_percentage -ge 90) { "Green" } elseif ($stats.coverage_percentage -ge 70) { "Yellow" } else { "Red" })
    Write-Host ""

    Write-Host "By Entity Type:" -ForegroundColor Cyan
    foreach ($entity in $stats.by_entity_type.PSObject.Properties) {
        $name = $entity.Name
        $data = $entity.Value
        $coverage = $data.coverage_percentage
        $color = if ($coverage -ge 90) { "Green" } elseif ($coverage -ge 70) { "Yellow" } else { "Red" }

        Write-Host "  $name`: $($data.records_with_context)/$($data.total_records) ($coverage%)" -ForegroundColor $color
    }
} catch {
    Write-Host "⚠️  Failed to fetch statistics: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Context Generation Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test semantic search in ChatERP: http://localhost:5000/chaterp.html" -ForegroundColor White
Write-Host "  2. Try queries like:" -ForegroundColor White
Write-Host "     - 'Who sells office supplies?'" -ForegroundColor Gray
Write-Host "     - 'Which account for rent payments?'" -ForegroundColor Gray
Write-Host "     - 'Find vendors for IT equipment'" -ForegroundColor Gray
Write-Host "  3. View context coverage: curl http://localhost:8007/context-stats?tenant_id=$TENANT_ID" -ForegroundColor White
Write-Host ""
