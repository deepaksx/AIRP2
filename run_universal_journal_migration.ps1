# Universal Journal Migration Script
# Migrates AIRP from sub-ledger tables to Universal Journal architecture
# Date: 2025-10-21
# Version: v2.12.0

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Universal Journal Migration" -ForegroundColor Cyan
Write-Host "AIRP v2.12.0" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Database connection details
$DB_HOST = "localhost"
$DB_PORT = "5432"
$DB_NAME = "airp_master"
$DB_USER = "airp_admin"
$DB_PASSWORD = "airp_secure_2024"

# Set environment variable for password
$env:PGPASSWORD = $DB_PASSWORD

Write-Host "[STEP 1] Pre-Migration Backup..." -ForegroundColor Yellow

# Create backup directory
$BACKUP_DIR = "C:/Dev/AIRP2/backups"
if (-not (Test-Path $BACKUP_DIR)) {
    New-Item -Path $BACKUP_DIR -ItemType Directory | Out-Null
}

$BACKUP_FILE = "$BACKUP_DIR/airp_master_pre_universal_journal_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"

Write-Host "Creating database backup: $BACKUP_FILE" -ForegroundColor Gray

try {
    # Create backup using docker exec
    docker exec -i airp-postgres pg_dump -U $DB_USER -d $DB_NAME > $BACKUP_FILE
    Write-Host "✅ Backup created successfully`n" -ForegroundColor Green
} catch {
    Write-Host "❌ Backup failed: $_" -ForegroundColor Red
    Write-Host "Migration aborted for safety." -ForegroundColor Red
    exit 1
}

Write-Host "[STEP 2] Verify Database Connection..." -ForegroundColor Yellow

try {
    $testQuery = "SELECT COUNT(*) FROM journal_entry_lines;"
    $result = docker exec -i airp-postgres psql -U $DB_USER -d $DB_NAME -t -c $testQuery
    Write-Host "✅ Database connection successful" -ForegroundColor Green
    Write-Host "   Current journal_entry_lines count: $($result.Trim())`n" -ForegroundColor Gray
} catch {
    Write-Host "❌ Database connection failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "[STEP 3] Pre-Migration Data Counts..." -ForegroundColor Yellow

$queries = @{
    "ap_invoices" = "SELECT COUNT(*) FROM ap_invoices;"
    "ar_invoices" = "SELECT COUNT(*) FROM ar_invoices;"
    "journal_entries" = "SELECT COUNT(*) FROM journal_entries;"
    "journal_entry_lines" = "SELECT COUNT(*) FROM journal_entry_lines;"
}

$preCounts = @{}

foreach ($table in $queries.Keys) {
    try {
        $count = docker exec -i airp-postgres psql -U $DB_USER -d $DB_NAME -t -c $queries[$table]
        $preCounts[$table] = $count.Trim()
        Write-Host "  $table : $($preCounts[$table])" -ForegroundColor Gray
    } catch {
        Write-Host "  $table : ERROR" -ForegroundColor Red
        $preCounts[$table] = "ERROR"
    }
}

Write-Host ""

Write-Host "[STEP 4] Execute Migration SQL..." -ForegroundColor Yellow
Write-Host "Migration file: schemas/sql/migrations/003_universal_journal_metadata.sql" -ForegroundColor Gray

try {
    # Execute migration SQL
    Get-Content "C:/Dev/AIRP2/schemas/sql/migrations/003_universal_journal_metadata.sql" | docker exec -i airp-postgres psql -U $DB_USER -d $DB_NAME 2>&1 | ForEach-Object {
        if ($_ -match "ERROR|FATAL") {
            Write-Host $_ -ForegroundColor Red
        } elseif ($_ -match "NOTICE|WARNING") {
            Write-Host $_ -ForegroundColor Yellow
        } elseif ($_ -match "CREATE|ALTER|UPDATE|INSERT") {
            Write-Host $_ -ForegroundColor Green
        } else {
            Write-Host $_ -ForegroundColor Gray
        }
    }

    Write-Host "`n✅ Migration SQL executed`n" -ForegroundColor Green
} catch {
    Write-Host "❌ Migration failed: $_" -ForegroundColor Red
    Write-Host "`nAttempting rollback from backup..." -ForegroundColor Yellow
    Write-Host "Run: docker exec -i airp-postgres psql -U $DB_USER -d $DB_NAME < $BACKUP_FILE" -ForegroundColor Yellow
    exit 1
}

Write-Host "[STEP 5] Post-Migration Verification..." -ForegroundColor Yellow

# Verify views created
$verifyQueries = @{
    "vw_ap_invoices" = "SELECT COUNT(*) FROM vw_ap_invoices;"
    "vw_ar_invoices" = "SELECT COUNT(*) FROM vw_ar_invoices;"
    "mv_ap_aging" = "SELECT COUNT(*) FROM mv_ap_aging;"
    "mv_ar_aging" = "SELECT COUNT(*) FROM mv_ar_aging;"
}

$postCounts = @{}
$allSuccess = $true

foreach ($view in $verifyQueries.Keys) {
    try {
        $count = docker exec -i airp-postgres psql -U $DB_USER -d $DB_NAME -t -c $verifyQueries[$view]
        $postCounts[$view] = $count.Trim()
        Write-Host "  $view : $($postCounts[$view])" -ForegroundColor Green
    } catch {
        Write-Host "  $view : ERROR" -ForegroundColor Red
        $postCounts[$view] = "ERROR"
        $allSuccess = $false
    }
}

Write-Host ""

# Verify metadata field
Write-Host "[STEP 6] Verify Metadata Field..." -ForegroundColor Yellow

try {
    $metadataQuery = "SELECT COUNT(*) FROM journal_entry_lines WHERE metadata IS NOT NULL AND jsonb_typeof(metadata) = 'object';"
    $metadataCount = docker exec -i airp-postgres psql -U $DB_USER -d $DB_NAME -t -c $metadataQuery
    Write-Host "  Rows with metadata: $($metadataCount.Trim())" -ForegroundColor Green

    $invoiceMetadataQuery = "SELECT COUNT(*) FROM journal_entry_lines WHERE metadata->>'invoice_number' IS NOT NULL;"
    $invoiceMetadataCount = docker exec -i airp-postgres psql -U $DB_USER -d $DB_NAME -t -c $invoiceMetadataQuery
    Write-Host "  Rows with invoice_number in metadata: $($invoiceMetadataCount.Trim())" -ForegroundColor Green
} catch {
    Write-Host "  Metadata verification: ERROR" -ForegroundColor Red
    $allSuccess = $false
}

Write-Host ""

# Verify archived tables
Write-Host "[STEP 7] Verify Archived Tables..." -ForegroundColor Yellow

try {
    $archiveQuery = "SELECT COUNT(*) FROM ap_invoices_archive_20251021;"
    $archiveCount = docker exec -i airp-postgres psql -U $DB_USER -d $DB_NAME -t -c $archiveQuery
    Write-Host "  ap_invoices_archive_20251021: $($archiveCount.Trim())" -ForegroundColor Green
} catch {
    Write-Host "  ap_invoices_archive_20251021: Not found or ERROR" -ForegroundColor Yellow
}

try {
    $archiveQuery = "SELECT COUNT(*) FROM ar_invoices_archive_20251021;"
    $archiveCount = docker exec -i airp-postgres psql -U $DB_USER -d $DB_NAME -t -c $archiveQuery
    Write-Host "  ar_invoices_archive_20251021: $($archiveCount.Trim())" -ForegroundColor Green
} catch {
    Write-Host "  ar_invoices_archive_20251021: Not found or ERROR" -ForegroundColor Yellow
}

Write-Host ""

# Verify old tables don't exist
Write-Host "[STEP 8] Verify Old Tables Removed..." -ForegroundColor Yellow

$checkOldTables = @"
SELECT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_name IN ('ap_invoices', 'ar_invoices')
) as old_tables_exist;
"@

try {
    $oldTablesExist = docker exec -i airp-postgres psql -U $DB_USER -d $DB_NAME -t -c $checkOldTables
    if ($oldTablesExist.Trim() -eq "f") {
        Write-Host "  ✅ Old tables (ap_invoices, ar_invoices) successfully removed" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Old tables still exist - migration may be incomplete" -ForegroundColor Yellow
        $allSuccess = $false
    }
} catch {
    Write-Host "  ❌ Could not verify old tables removal" -ForegroundColor Red
    $allSuccess = $false
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MIGRATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nPre-Migration Counts:" -ForegroundColor White
foreach ($table in $preCounts.Keys) {
    Write-Host "  $table : $($preCounts[$table])" -ForegroundColor Gray
}

Write-Host "`nPost-Migration Counts:" -ForegroundColor White
foreach ($view in $postCounts.Keys) {
    Write-Host "  $view : $($postCounts[$view])" -ForegroundColor Gray
}

Write-Host "`nBackup Location:" -ForegroundColor White
Write-Host "  $BACKUP_FILE" -ForegroundColor Gray

Write-Host "`nMigration Status:" -ForegroundColor White
if ($allSuccess) {
    Write-Host "  ✅ MIGRATION SUCCESSFUL!" -ForegroundColor Green
    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "  1. Restart affected services (AP, AR, Reporting)" -ForegroundColor Gray
    Write-Host "  2. Run integration tests" -ForegroundColor Gray
    Write-Host "  3. Verify ChatERP queries work" -ForegroundColor Gray
    Write-Host "  4. Test aging reports" -ForegroundColor Gray
} else {
    Write-Host "  ⚠️  MIGRATION COMPLETED WITH WARNINGS" -ForegroundColor Yellow
    Write-Host "`nReview errors above and verify manually." -ForegroundColor Yellow
    Write-Host "Rollback command if needed:" -ForegroundColor Yellow
    Write-Host "  docker exec -i airp-postgres psql -U $DB_USER -d $DB_NAME < $BACKUP_FILE" -ForegroundColor Gray
}

Write-Host "`n========================================`n" -ForegroundColor Cyan

# Clear password from environment
$env:PGPASSWORD = $null
