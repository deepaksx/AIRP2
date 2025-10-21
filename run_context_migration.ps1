#!/usr/bin/env pwsh
# AIRP v2.11.0 - AI Context Migration Script
# Runs database migration to add AI context fields

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "AIRP v2.11.0 - AI Context Metadata Migration" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check if PostgreSQL is running
Write-Host "[1/3] Checking PostgreSQL connection..." -ForegroundColor Yellow
$pgStatus = docker ps --filter "name=airp-postgres" --filter "status=running" --format "{{.Names}}"

if ($pgStatus -ne "airp-postgres") {
    Write-Host "❌ PostgreSQL is not running!" -ForegroundColor Red
    Write-Host "   Please start it with: docker compose up -d postgres" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ PostgreSQL is running" -ForegroundColor Green
Write-Host ""

# Run migration
Write-Host "[2/3] Running AI context migration..." -ForegroundColor Yellow
$migrationFile = "C:/Dev/AIRP2/schemas/sql/migrations/002_add_ai_context_fields.sql"

if (-Not (Test-Path $migrationFile)) {
    Write-Host "❌ Migration file not found: $migrationFile" -ForegroundColor Red
    exit 1
}

# Execute migration using docker exec
docker exec -i airp-postgres psql -U airp_admin -d airp_master < $migrationFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Migration completed successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Migration failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Verify migration
Write-Host "[3/3] Verifying migration..." -ForegroundColor Yellow

$verifyQuery = @"
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'vendors'
  AND column_name LIKE 'ai_context%'
ORDER BY column_name;
"@

Write-Host "   Checking for AI context columns in vendors table..." -ForegroundColor Gray
$result = docker exec -i airp-postgres psql -U airp_admin -d airp_master -c $verifyQuery

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Verification successful - AI context columns found" -ForegroundColor Green
} else {
    Write-Host "⚠️  Verification query failed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Migration Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Start AI Context Generator: docker compose up -d ai-context-generator" -ForegroundColor White
Write-Host "  2. Generate context for existing data: .\run_generate_contexts.ps1" -ForegroundColor White
Write-Host "  3. Test context search in ChatERP: http://localhost:5000/chaterp.html" -ForegroundColor White
Write-Host ""
