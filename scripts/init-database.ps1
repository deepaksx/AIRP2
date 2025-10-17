# AIRP v2.0 - Database Initialization Script
# Loads database schema and creates test data

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "AIRP v2.0 - Database Initialization" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Check if PostgreSQL container is running
Write-Host "[1/4] Checking PostgreSQL container..." -ForegroundColor Yellow
$pgContainer = docker ps --filter "name=airp-postgres" --format "{{.Names}}"

if (-not $pgContainer) {
    Write-Host "❌ PostgreSQL container not running!" -ForegroundColor Red
    Write-Host "   Run: docker compose -f docker-compose.dev.yml up -d postgres" -ForegroundColor White
    exit 1
}

Write-Host "✓ PostgreSQL container is running" -ForegroundColor Green
Write-Host ""

# Wait for PostgreSQL to be fully ready
Write-Host "[2/4] Waiting for PostgreSQL to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$retries = 0
$maxRetries = 10
$ready = $false

while (-not $ready -and $retries -lt $maxRetries) {
    $result = docker exec airp-postgres pg_isready -U airp_admin -d airp_master 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ready = $true
    } else {
        $retries++
        Write-Host "   Waiting... (attempt $retries/$maxRetries)" -ForegroundColor Gray
        Start-Sleep -Seconds 2
    }
}

if (-not $ready) {
    Write-Host "❌ PostgreSQL failed to become ready" -ForegroundColor Red
    exit 1
}

Write-Host "✓ PostgreSQL is ready" -ForegroundColor Green
Write-Host ""

# Load DDL schema
Write-Host "[3/4] Loading database schema..." -ForegroundColor Yellow

$ddlPath = "C:\Dev\AIRP2\schemas\sql\ddl.sql"

if (-not (Test-Path $ddlPath)) {
    Write-Host "❌ DDL file not found: $ddlPath" -ForegroundColor Red
    exit 1
}

# Copy DDL to container and execute
docker cp $ddlPath airp-postgres:/tmp/ddl.sql
$loadResult = docker exec airp-postgres psql -U airp_admin -d airp_master -f /tmp/ddl.sql 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to load schema" -ForegroundColor Red
    Write-Host $loadResult -ForegroundColor Red
    exit 1
}

Write-Host "✓ Database schema loaded successfully" -ForegroundColor Green
Write-Host ""

# Create test tenant and basic data
Write-Host "[4/4] Creating test data..." -ForegroundColor Yellow

$testDataSQL = @'
INSERT INTO tenants (tenant_id, tenant_name, tenant_code, base_currency, timezone, fiscal_year_end)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'Demo Company LLC', 'DEMO001', 'AED', 'Asia/Dubai', 12)
ON CONFLICT (tenant_id) DO NOTHING;

INSERT INTO chart_of_accounts (account_id, tenant_id, account_code, account_name, account_type, parent_account_id, is_active)
VALUES
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '1000', 'Cash', 'asset', NULL, true),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '1200', 'Accounts Receivable', 'asset', NULL, true),
    ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', '2100', 'Accounts Payable', 'liability', NULL, true),
    ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', '4000', 'Revenue - Product Sales', 'revenue', NULL, true),
    ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', '5100', 'Cost of Goods Sold', 'expense', NULL, true),
    ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000001', '5500', 'Office Supplies', 'expense', NULL, true),
    ('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000001', '5900', 'IT & Software', 'expense', NULL, true)
ON CONFLICT (account_id) DO NOTHING;

INSERT INTO vendors (vendor_id, tenant_id, vendor_code, vendor_name, email, default_currency, payment_terms_days, status)
VALUES
    ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'VEN001', 'ABC Suppliers LLC', 'supplier@abc.ae', 'AED', 30, 'active')
ON CONFLICT (vendor_id) DO NOTHING;

INSERT INTO customers (customer_id, tenant_id, customer_code, customer_name, email, default_currency, payment_terms_days, credit_limit, status)
VALUES
    ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'CUS001', 'XYZ Trading LLC', 'customer@xyz.ae', 'AED', 30, 100000, 'active')
ON CONFLICT (customer_id) DO NOTHING;

INSERT INTO bank_accounts (account_id, tenant_id, bank_name, account_number, iban, currency_code, current_balance, status)
VALUES
    ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Emirates NBD', '1234567890', 'AE070331234567890123456', 'AED', 500000, 'active')
ON CONFLICT (account_id) DO NOTHING;
'@

# Write test data SQL to temp file
$testDataSQL | Out-File -FilePath "C:\Dev\AIRP2\schemas\sql\test-data.sql" -Encoding UTF8

# Load test data
docker cp "C:\Dev\AIRP2\schemas\sql\test-data.sql" airp-postgres:/tmp/test-data.sql
$testResult = docker exec airp-postgres psql -U airp_admin -d airp_master -f /tmp/test-data.sql 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠ Warning: Some test data may not have loaded" -ForegroundColor Yellow
} else {
    Write-Host "✓ Test data created successfully" -ForegroundColor Green
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "✓ Database initialization complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test Tenant ID: 00000000-0000-0000-0000-000000000001" -ForegroundColor White
Write-Host "Test Tenant Code: DEMO001" -ForegroundColor White
Write-Host ""
