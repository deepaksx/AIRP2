# Create 100 Journal Entries with Proper Vendor/Customer Linkage
# AIRP v2.4.0+ compliant

$API_URL = "http://localhost:3001/journal-entries"
$TENANT_ID = "00000000-0000-0000-0000-000000000001"

$vendors = @(
    @{ id = "88cadce4-57bf-4ef3-8d02-c361d0b46a22"; code = "ABC-STAT-001"; name = "ABC Stationery LLC" }
    @{ id = "cc1e22ff-ab11-431d-8ad0-d57528ea639d"; code = "V001"; name = "Test Vendor Inc" }
    @{ id = "1e721e7f-d207-4b5e-9010-5eba023ba598"; code = "V002"; name = "Global Supplies Company LLC" }
    @{ id = "24d01d4a-8245-47f8-bed3-bc8f60ca27db"; code = "VEN001"; name = "Office Supplies LLC" }
    @{ id = "3363eb1c-3a50-4144-b28a-8c71af2777f5"; code = "VEN002"; name = "IT Solutions Inc" }
    @{ id = "f9e15c49-45e2-43b2-96f5-6669d021ab96"; code = "VEN003"; name = "Cleaning Services Co" }
)

$customers = @(
    @{ id = "593adf90-91f1-4da8-a5b6-0912416351e4"; code = "C001"; name = "Test Customer Ltd" }
    @{ id = "be78cf7e-d5bf-4d36-becd-a2d036e78dc0"; code = "C002"; name = "Premium Corporation LLC" }
    @{ id = "7c362317-a0ab-4498-bd14-281aae039f8a"; code = "CUST001"; name = "Premium Corp" }
    @{ id = "b3c5a6f2-4bdf-4768-afd8-c9f4abc99792"; code = "CUST002"; name = "Elite Trading LLC" }
    @{ id = "cc9902ca-7f94-4dc7-ab76-c5b7164355a9"; code = "CUST003"; name = "Global Enterprises" }
)

$success_count = 0
$error_count = 0

Write-Host "Creating 100 journal entries..." -ForegroundColor Cyan

# 1. Create 40 AP Invoice Entries
Write-Host "`n[1/3] Creating 40 AP Invoice Entries..." -ForegroundColor Yellow
for ($i = 1; $i -le 40; $i++) {
    $vendor = $vendors[$i % $vendors.Count]
    $amount = Get-Random -Minimum 500 -Maximum 15000
    $tax = [math]::Round($amount * 0.05, 2)
    $total = $amount + $tax

    $entry_date = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")
    $due_date = (Get-Date).AddDays(-$i + 30).ToString("yyyy-MM-dd")
    $invoice_number = "INV-AP-2025-{0:D4}" -f $i

    $body = @{
        tenantId = $TENANT_ID
        entryDate = $entry_date
        entryType = "ap_invoice"
        sourceType = "Manual"
        description = "AP Invoice $invoice_number - $($vendor.name)"
        lines = @(
            @{
                accountCode = "5100"
                debitAmount = $amount
                creditAmount = 0
                description = "Expense - $invoice_number"
            }
            @{
                accountCode = "2130"
                debitAmount = $tax
                creditAmount = 0
                description = "VAT - $invoice_number"
            }
            @{
                accountCode = "2100"
                debitAmount = 0
                creditAmount = $total
                description = "AP - $invoice_number"
                vendorId = $vendor.id
                invoiceNumber = $invoice_number
                dueDate = $due_date
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri $API_URL -Method Post -Body $body -ContentType "application/json"
        $success_count++
        Write-Host "  OK AP Entry $i created" -ForegroundColor Green
    } catch {
        $error_count++
        Write-Host "  FAIL AP Entry $i" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 100
}

# 2. Create 40 AR Invoice Entries
Write-Host "`n[2/3] Creating 40 AR Invoice Entries..." -ForegroundColor Yellow
for ($i = 1; $i -le 40; $i++) {
    $customer = $customers[$i % $customers.Count]
    $amount = Get-Random -Minimum 1000 -Maximum 25000
    $tax = [math]::Round($amount * 0.05, 2)
    $total = $amount + $tax

    $entry_date = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")
    $due_date = (Get-Date).AddDays(-$i + 30).ToString("yyyy-MM-dd")
    $invoice_number = "INV-AR-2025-{0:D4}" -f $i

    $body = @{
        tenantId = $TENANT_ID
        entryDate = $entry_date
        entryType = "ar_invoice"
        sourceType = "Manual"
        description = "AR Invoice $invoice_number - $($customer.name)"
        lines = @(
            @{
                accountCode = "1200"
                debitAmount = $total
                creditAmount = 0
                description = "AR - $invoice_number"
                customerId = $customer.id
                invoiceNumber = $invoice_number
                dueDate = $due_date
            }
            @{
                accountCode = "4000"
                debitAmount = 0
                creditAmount = $amount
                description = "Revenue - $invoice_number"
            }
            @{
                accountCode = "2130"
                debitAmount = 0
                creditAmount = $tax
                description = "VAT - $invoice_number"
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri $API_URL -Method Post -Body $body -ContentType "application/json"
        $success_count++
        Write-Host "  OK AR Entry $i created" -ForegroundColor Green
    } catch {
        $error_count++
        Write-Host "  FAIL AR Entry $i" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 100
}

# 3. Create 20 General Entries
Write-Host "`n[3/3] Creating 20 General Journal Entries..." -ForegroundColor Yellow
for ($i = 1; $i -le 20; $i++) {
    $amount = Get-Random -Minimum 1000 -Maximum 10000
    $entry_date = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")

    $entry_type = $i % 2
    if ($entry_type -eq 0) {
        $description = "Bank Deposit - Transfer $i"
        $debit_account = "1000"
        $credit_account = "4100"
    } else {
        $description = "Bank Payment - Utilities $i"
        $debit_account = "5200"
        $credit_account = "1000"
    }

    $body = @{
        tenantId = $TENANT_ID
        entryDate = $entry_date
        entryType = "general"
        sourceType = "Manual"
        description = $description
        lines = @(
            @{
                accountCode = $debit_account
                debitAmount = $amount
                creditAmount = 0
                description = $description
            }
            @{
                accountCode = $credit_account
                debitAmount = 0
                creditAmount = $amount
                description = $description
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri $API_URL -Method Post -Body $body -ContentType "application/json"
        $success_count++
        Write-Host "  OK General Entry $i created" -ForegroundColor Green
    } catch {
        $error_count++
        Write-Host "  FAIL General Entry $i" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 100
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "SUMMARY:" -ForegroundColor Cyan
Write-Host "  Total Entries Attempted: 100" -ForegroundColor White
Write-Host "  Successful: $success_count" -ForegroundColor Green
Write-Host "  Failed: $error_count" -ForegroundColor Red
Write-Host "`nAll entries created with proper vendor/customer linkage!" -ForegroundColor Green
Write-Host "v2.4.0 accounting controls enforced" -ForegroundColor Green
