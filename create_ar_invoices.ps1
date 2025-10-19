# Create 25 AR Invoices for Customer Ledger

$customers = @(
    @{id='593adf90-91f1-4da8-a5b6-0912416351e4'; code='C001'},
    @{id='be78cf7e-d5bf-4d36-becd-a2d036e78dc0'; code='C002'},
    @{id='7c362317-a0ab-4498-bd14-281aae039f8a'; code='CUST001'},
    @{id='b3c5a6f2-4bdf-4768-afd8-c9f4abc99792'; code='CUST002'},
    @{id='cc9902ca-7f94-4dc7-ab76-c5b7164355a9'; code='CUST003'}
)

Write-Host "`n================================================================================`n" -ForegroundColor Cyan
Write-Host "Creating 25 AR Invoices for Customer Ledger" -ForegroundColor Cyan
Write-Host "`n================================================================================`n" -ForegroundColor Cyan

$count = 0

for ($i = 1; $i -le 25; $i++) {
    $customer = $customers | Get-Random
    $amount = Get-Random -Minimum 5000 -Maximum 100000
    $amount = [Math]::Round($amount, 2)
    $tax = [Math]::Round($amount * 0.05, 2)
    $total = $amount + $tax

    $payload = @{
        tenant_id = '00000000-0000-0000-0000-000000000001'
        customer_id = $customer.id
        invoice_number = "AR-2025-$(Get-Random -Minimum 1000 -Maximum 9999)"
        invoice_date = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 90)).ToString('yyyy-MM-dd')
        due_date = (Get-Date).AddDays((Get-Random -Minimum 15 -Maximum 60)).ToString('yyyy-MM-dd')
        subtotal = $amount
        tax_amount = $tax
        total_amount = $total
        amount_outstanding = $total
        currency = 'AED'
        status = 'posted'
        payment_status = 'unpaid'
        metadata = @{
            payment_terms = 'Net 30'
            description = "Sales invoice $i"
        }
        lines = @(
            @{
                line_number = 1
                description = 'Product sales and services'
                quantity = 1
                unit_price = $amount
                line_amount = $amount
            }
        )
    } | ConvertTo-Json -Depth 5

    try {
        $response = Invoke-RestMethod -Uri 'http://localhost:3004/invoices' -Method Post -Body $payload -ContentType 'application/json' -ErrorAction Stop
        $count++
        Write-Host "  [OK] AR Invoice $i - $($customer.code) - AED $total" -ForegroundColor DarkGreen
    } catch {
        Write-Host "  [FAIL] AR Invoice $i - $_" -ForegroundColor Red
    }
}

Write-Host "`n================================================================================`n" -ForegroundColor Cyan
Write-Host "Total AR invoices created: $count / 25" -ForegroundColor $(if ($count -ge 25) { "Green" } else { "Yellow" })
Write-Host "`n================================================================================`n" -ForegroundColor Cyan
