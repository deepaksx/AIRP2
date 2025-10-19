# AIRP v2.0 - Reporting APIs Test Script (PowerShell)
# This script tests all the implemented reporting endpoints

$BaseUrl = "http://localhost:3008"
$TenantId = "00000000-0000-0000-0000-000000000001"
$VendorId = "20000000-0000-0000-0000-000000000001"
$CustomerId = "30000000-0000-0000-0000-000000000001"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "AIRP v2.0 - Reporting APIs Test Suite" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Vendor Ledger
Write-Host "1. Testing Vendor Ledger API..." -ForegroundColor Yellow
$url = "$BaseUrl/reports/vendor-ledger?tenant_id=$TenantId&vendor_id=$VendorId"
Write-Host "URL: $url" -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri $url -Method Get
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 2: Customer Ledger
Write-Host "2. Testing Customer Ledger API..." -ForegroundColor Yellow
$url = "$BaseUrl/reports/customer-ledger?tenant_id=$TenantId&customer_id=$CustomerId"
Write-Host "URL: $url" -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri $url -Method Get
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 3: Account Balances
Write-Host "3. Testing Account Balances API..." -ForegroundColor Yellow
$url = "$BaseUrl/reports/account-balances?tenant_id=$TenantId"
Write-Host "URL: $url" -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri $url -Method Get
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 4: Income Statement
Write-Host "4. Testing Income Statement API..." -ForegroundColor Yellow
$url = "$BaseUrl/reports/income-statement?tenant_id=$TenantId&start_date=2024-01-01&end_date=2024-12-31"
Write-Host "URL: $url" -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri $url -Method Get
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 5: Balance Sheet
Write-Host "5. Testing Balance Sheet API..." -ForegroundColor Yellow
$url = "$BaseUrl/reports/balance-sheet?tenant_id=$TenantId&as_of_date=2024-12-31"
Write-Host "URL: $url" -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri $url -Method Get
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 6: Cash Flow Statement
Write-Host "6. Testing Cash Flow Statement API..." -ForegroundColor Yellow
$url = "$BaseUrl/reports/cash-flow?tenant_id=$TenantId&start_date=2024-01-01&end_date=2024-12-31"
Write-Host "URL: $url" -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri $url -Method Get
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 7: Trial Balance (existing endpoint)
Write-Host "7. Testing Trial Balance API (Existing)..." -ForegroundColor Yellow
$url = "$BaseUrl/reports/trial-balance?tenant_id=$TenantId"
Write-Host "URL: $url" -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri $url -Method Get
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 8: AP Aging (existing endpoint)
Write-Host "8. Testing AP Aging API (Existing)..." -ForegroundColor Yellow
$url = "$BaseUrl/reports/aging/ap?tenant_id=$TenantId"
Write-Host "URL: $url" -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri $url -Method Get
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 9: AR Aging (existing endpoint)
Write-Host "9. Testing AR Aging API (Existing)..." -ForegroundColor Yellow
$url = "$BaseUrl/reports/aging/ar?tenant_id=$TenantId"
Write-Host "URL: $url" -ForegroundColor Gray
try {
    $response = Invoke-RestMethod -Uri $url -Method Get
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Test Suite Complete!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
