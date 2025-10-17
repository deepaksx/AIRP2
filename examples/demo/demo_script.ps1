# AIRP v2.0 - End-to-End Demo Script (PowerShell)
# Demonstrates: Invoice Upload -> AI Classification -> Ledger Posting -> Verification

# Configuration
$LEDGER_WRITER = "http://localhost:3001"
$AI_ACCOUNTING = "http://localhost:8001"
$TENANT_ID = "550e8400-e29b-41d4-a716-446655440000"
$USER_ID = "user-cfo-001"

# Colors
$Green = "Green"
$Blue = "Cyan"
$Yellow = "Yellow"

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor $Blue
Write-Host "║                                                        ║" -ForegroundColor $Blue
Write-Host "║  AIRP v2.0 - AI-Native Financial ERP Demo             ║" -ForegroundColor $Blue
Write-Host "║  End-to-End Invoice Processing Workflow               ║" -ForegroundColor $Blue
Write-Host "║                                                        ║" -ForegroundColor $Blue
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor $Blue
Write-Host ""

# Step 1: Health Checks
Write-Host "Step 1: Checking service health..." -ForegroundColor $Blue
Write-Host ""

Write-Host "Checking Ledger Writer..."
try {
    $health1 = Invoke-RestMethod -Uri "$LEDGER_WRITER/health" -Method Get
    $health1 | ConvertTo-Json
    Write-Host ""
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Checking AI Auto-Accounting..."
try {
    $health2 = Invoke-RestMethod -Uri "$AI_ACCOUNTING/health" -Method Get
    $health2 | ConvertTo-Json
    Write-Host ""
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host "✓ All services are healthy" -ForegroundColor $Green
Write-Host ""
Start-Sleep -Seconds 2

# Step 2: AI Classification
Write-Host "Step 2: Classifying invoice with AI..." -ForegroundColor $Blue
Write-Host ""

$classifyBody = @{
    tenant_id = $TENANT_ID
    invoice_id = "demo-ps-$(Get-Date -Format 'yyyyMMddHHmmss')"
    vendor_name = "Dubai Marketing Agency"
    transaction_type = "AP"
    lines = @(
        @{
            line_number = 1
            description = "Social media advertising campaign for Q1 2024"
            amount = 15000.00
            quantity = 1.0
        }
    )
} | ConvertTo-Json

try {
    $aiResponse = Invoke-RestMethod -Uri "$AI_ACCOUNTING/classify" `
        -Method Post `
        -ContentType "application/json" `
        -Body $classifyBody

    Write-Host "AI Response:" -ForegroundColor $Yellow
    $aiResponse | ConvertTo-Json -Depth 10
    Write-Host ""

    $accountCode = $aiResponse.suggestions[0].account_code
    $confidence = $aiResponse.suggestions[0].confidence_score
    $reasoning = $aiResponse.suggestions[0].reasoning

    Write-Host "✓ AI Classification Complete" -ForegroundColor $Green
    Write-Host "  Account Code: $accountCode" -ForegroundColor $Yellow
    Write-Host "  Confidence: $confidence" -ForegroundColor $Yellow
    Write-Host "  Reasoning: $reasoning" -ForegroundColor $Yellow
    Write-Host ""
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 2

# Step 3: Post Journal Entry
Write-Host "Step 3: Posting journal entry to immutable ledger..." -ForegroundColor $Blue
Write-Host ""

$today = Get-Date -Format "yyyy-MM-dd"
$subtotal = 15000.00
$vat = $subtotal * 0.05
$total = $subtotal + $vat

$jeBody = @{
    tenantId = $TENANT_ID
    entryDate = $today
    entryType = "Standard"
    description = "Marketing Expense - Dubai Marketing Agency"
    userId = $USER_ID
    sourceType = "AP"
    aiGenerated = $true
    aiConfidenceScore = $confidence
    lines = @(
        @{
            accountCode = $accountCode
            debitAmount = $total
            creditAmount = 0
            description = "Marketing & Advertising (incl. 5% VAT)"
        },
        @{
            accountCode = "2100"
            debitAmount = 0
            creditAmount = $total
            description = "Accounts Payable - Dubai Marketing Agency"
        }
    )
} | ConvertTo-Json -Depth 10

try {
    $jeResponse = Invoke-RestMethod -Uri "$LEDGER_WRITER/journal-entries" `
        -Method Post `
        -ContentType "application/json" `
        -Body $jeBody

    Write-Host "Journal Entry Response:" -ForegroundColor $Yellow
    $jeResponse | ConvertTo-Json -Depth 10
    Write-Host ""

    $entryId = $jeResponse.entryId
    $eventId = $jeResponse.event.event_id

    Write-Host "✓ Journal Entry Posted" -ForegroundColor $Green
    Write-Host "  Entry ID: $entryId" -ForegroundColor $Yellow
    Write-Host "  Event ID: $eventId" -ForegroundColor $Yellow
    Write-Host ""
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 2

# Step 4: Verify Event Store
Write-Host "Step 4: Verifying immutable event store..." -ForegroundColor $Blue
Write-Host ""

try {
    $events = Invoke-RestMethod -Uri "$LEDGER_WRITER/events/aggregate/${entryId}?tenantId=$TENANT_ID" -Method Get
    Write-Host "Event Store Response:" -ForegroundColor $Yellow
    $events | ConvertTo-Json -Depth 10
    Write-Host ""
    Write-Host "✓ Event retrieved from immutable store" -ForegroundColor $Green
    Write-Host ""
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Start-Sleep -Seconds 2

# Step 5: Verify Integrity
Write-Host "Step 5: Verifying event integrity (checksum)..." -ForegroundColor $Blue
Write-Host ""

try {
    $integrity = Invoke-RestMethod -Uri "$LEDGER_WRITER/events/verify/$eventId" -Method Get
    Write-Host "Integrity Check:" -ForegroundColor $Yellow
    $integrity | ConvertTo-Json
    Write-Host ""

    if ($integrity.isValid) {
        Write-Host "✓ Event integrity verified - checksum matches" -ForegroundColor $Green
    } else {
        Write-Host "✗ Event integrity check failed!" -ForegroundColor Red
    }
    Write-Host ""
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Start-Sleep -Seconds 2

# Summary
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor $Blue
Write-Host "║                                                        ║" -ForegroundColor $Blue
Write-Host "║  Demo Complete! ✓                                      ║" -ForegroundColor $Blue
Write-Host "║                                                        ║" -ForegroundColor $Blue
Write-Host "║  What Just Happened:                                   ║" -ForegroundColor $Blue
Write-Host "║  1. AI classified invoice line → Marketing (5700)      ║" -ForegroundColor $Blue
Write-Host "║  2. Posted journal entry to immutable ledger           ║" -ForegroundColor $Blue
Write-Host "║  3. Event stored with SHA-256 checksum                 ║" -ForegroundColor $Blue
Write-Host "║  4. Verified event integrity                           ║" -ForegroundColor $Blue
Write-Host "║  5. Complete audit trail maintained                    ║" -ForegroundColor $Blue
Write-Host "║                                                        ║" -ForegroundColor $Blue
Write-Host "║  Key Features Demonstrated:                            ║" -ForegroundColor $Blue
Write-Host "║  • Event sourcing with immutability                    ║" -ForegroundColor $Blue
Write-Host "║  • AI-powered GL classification                        ║" -ForegroundColor $Blue
Write-Host "║  • Confidence scoring & explainability                 ║" -ForegroundColor $Blue
Write-Host "║  • Cryptographic integrity verification                ║" -ForegroundColor $Blue
Write-Host "║  • Complete audit trail (who, what, when, why)         ║" -ForegroundColor $Blue
Write-Host "║                                                        ║" -ForegroundColor $Blue
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor $Blue
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor $Yellow
Write-Host "  • View Swagger docs: $LEDGER_WRITER/api/docs"
Write-Host "  • Explore AI service: $AI_ACCOUNTING/docs"
Write-Host "  • Check Grafana dashboards: http://localhost:3100"
Write-Host "  • Query Kafka events: http://localhost:8080"
Write-Host ""

Write-Host "Thank you for exploring AIRP v2.0!" -ForegroundColor $Green
Write-Host ""
