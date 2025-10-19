#!/bin/bash

TENANT="00000000-0000-0000-0000-000000000001"
BASE_URL="http://localhost"
ERRORS=0
SUCCESS=0

echo "=========================================="
echo "AIRP v2.0 - Comprehensive Page API Testing"
echo "=========================================="
echo ""

test_api() {
    local name="$1"
    local url="$2"
    local expected_status="${3:-200}"

    echo -n "Testing $name... "
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url")

    if [ "$response" = "$expected_status" ]; then
        echo "✅ OK (HTTP $response)"
        ((SUCCESS++))
    else
        echo "❌ FAIL (HTTP $response, expected $expected_status)"
        ((ERRORS++))
    fi
}

echo "=== 1. MASTER DATA APIs ==="
test_api "Chart of Accounts" "$BASE_URL:3001/chart-of-accounts?tenant_id=$TENANT"
test_api "Vendors List" "$BASE_URL:3003/vendors?tenant_id=$TENANT"
test_api "Customers List" "$BASE_URL:3004/customers?tenant_id=$TENANT"
test_api "Bank Accounts" "$BASE_URL:3005/bank-accounts?tenant_id=$TENANT"
echo ""

echo "=== 2. EVENT STORE APIs ==="
test_api "Journal Entry Events" "$BASE_URL:3001/events/by-tenant/$TENANT?eventType=JournalEntryPosted"
test_api "All Events" "$BASE_URL:3001/events/by-tenant/$TENANT"
test_api "Event Stats" "$BASE_URL:3001/events/stats?tenantId=$TENANT"
echo ""

echo "=== 3. AP (Accounts Payable) APIs ==="
test_api "AP Invoices" "$BASE_URL:3003/invoices?tenant_id=$TENANT"
test_api "Vendor Ledger" "$BASE_URL:3008/reports/vendor-ledger?tenant_id=$TENANT"
echo ""

echo "=== 4. AR (Accounts Receivable) APIs ==="
test_api "AR Invoices" "$BASE_URL:3004/invoices?tenant_id=$TENANT"
test_api "Customer Ledger" "$BASE_URL:3008/reports/customer-ledger?tenant_id=$TENANT"
echo ""

echo "=== 5. REPORTING APIs ==="
test_api "Trial Balance" "$BASE_URL:3008/reports/trial-balance?tenant_id=$TENANT"
test_api "Account Balances" "$BASE_URL:3008/reports/account-balances?tenant_id=$TENANT"
test_api "Income Statement" "$BASE_URL:3008/reports/income-statement?tenant_id=$TENANT&start_date=2025-01-01&end_date=2025-12-31"
test_api "Balance Sheet" "$BASE_URL:3008/reports/balance-sheet?tenant_id=$TENANT&as_of_date=2025-12-31"
test_api "Cash Flow Statement" "$BASE_URL:3008/reports/cash-flow?tenant_id=$TENANT&start_date=2025-01-01&end_date=2025-12-31"
echo ""

echo "=== 6. AI SERVICES (Optional) ==="
test_api "AI Classification" "$BASE_URL:8001/health" 200
test_api "AI Reconciliation" "$BASE_URL:8002/health" 200
test_api "AI Policy Advisor" "$BASE_URL:8003/health" 200
test_api "AI Narrative" "$BASE_URL:8004/health" 200
test_api "AI Cash Flow" "$BASE_URL:8005/health" 200
test_api "AI Query Parser" "$BASE_URL:8006/health" 200
echo ""

echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "✅ Successful: $SUCCESS"
echo "❌ Failed: $ERRORS"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED - 100% FUNCTIONAL"
    exit 0
else
    echo "⚠️  FAILURES DETECTED - FIXING REQUIRED"
    exit 1
fi
