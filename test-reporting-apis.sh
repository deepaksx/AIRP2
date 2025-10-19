#!/bin/bash

# AIRP v2.0 - Reporting APIs Test Script
# This script tests all the implemented reporting endpoints

BASE_URL="http://localhost:3008"
TENANT_ID="00000000-0000-0000-0000-000000000001"
VENDOR_ID="20000000-0000-0000-0000-000000000001"
CUSTOMER_ID="30000000-0000-0000-0000-000000000001"

echo "=========================================="
echo "AIRP v2.0 - Reporting APIs Test Suite"
echo "=========================================="
echo ""

# Test 1: Vendor Ledger
echo "1. Testing Vendor Ledger API..."
echo "URL: ${BASE_URL}/reports/vendor-ledger?tenant_id=${TENANT_ID}&vendor_id=${VENDOR_ID}"
curl -s -X GET "${BASE_URL}/reports/vendor-ledger?tenant_id=${TENANT_ID}&vendor_id=${VENDOR_ID}" | json_pp 2>/dev/null || curl -s -X GET "${BASE_URL}/reports/vendor-ledger?tenant_id=${TENANT_ID}&vendor_id=${VENDOR_ID}"
echo ""
echo ""

# Test 2: Customer Ledger
echo "2. Testing Customer Ledger API..."
echo "URL: ${BASE_URL}/reports/customer-ledger?tenant_id=${TENANT_ID}&customer_id=${CUSTOMER_ID}"
curl -s -X GET "${BASE_URL}/reports/customer-ledger?tenant_id=${TENANT_ID}&customer_id=${CUSTOMER_ID}" | json_pp 2>/dev/null || curl -s -X GET "${BASE_URL}/reports/customer-ledger?tenant_id=${TENANT_ID}&customer_id=${CUSTOMER_ID}"
echo ""
echo ""

# Test 3: Account Balances
echo "3. Testing Account Balances API..."
echo "URL: ${BASE_URL}/reports/account-balances?tenant_id=${TENANT_ID}"
curl -s -X GET "${BASE_URL}/reports/account-balances?tenant_id=${TENANT_ID}" | json_pp 2>/dev/null || curl -s -X GET "${BASE_URL}/reports/account-balances?tenant_id=${TENANT_ID}"
echo ""
echo ""

# Test 4: Income Statement
echo "4. Testing Income Statement API..."
echo "URL: ${BASE_URL}/reports/income-statement?tenant_id=${TENANT_ID}&start_date=2024-01-01&end_date=2024-12-31"
curl -s -X GET "${BASE_URL}/reports/income-statement?tenant_id=${TENANT_ID}&start_date=2024-01-01&end_date=2024-12-31" | json_pp 2>/dev/null || curl -s -X GET "${BASE_URL}/reports/income-statement?tenant_id=${TENANT_ID}&start_date=2024-01-01&end_date=2024-12-31"
echo ""
echo ""

# Test 5: Balance Sheet
echo "5. Testing Balance Sheet API..."
echo "URL: ${BASE_URL}/reports/balance-sheet?tenant_id=${TENANT_ID}&as_of_date=2024-12-31"
curl -s -X GET "${BASE_URL}/reports/balance-sheet?tenant_id=${TENANT_ID}&as_of_date=2024-12-31" | json_pp 2>/dev/null || curl -s -X GET "${BASE_URL}/reports/balance-sheet?tenant_id=${TENANT_ID}&as_of_date=2024-12-31"
echo ""
echo ""

# Test 6: Cash Flow Statement
echo "6. Testing Cash Flow Statement API..."
echo "URL: ${BASE_URL}/reports/cash-flow?tenant_id=${TENANT_ID}&start_date=2024-01-01&end_date=2024-12-31"
curl -s -X GET "${BASE_URL}/reports/cash-flow?tenant_id=${TENANT_ID}&start_date=2024-01-01&end_date=2024-12-31" | json_pp 2>/dev/null || curl -s -X GET "${BASE_URL}/reports/cash-flow?tenant_id=${TENANT_ID}&start_date=2024-01-01&end_date=2024-12-31"
echo ""
echo ""

# Test 7: Trial Balance (existing endpoint)
echo "7. Testing Trial Balance API (Existing)..."
echo "URL: ${BASE_URL}/reports/trial-balance?tenant_id=${TENANT_ID}"
curl -s -X GET "${BASE_URL}/reports/trial-balance?tenant_id=${TENANT_ID}" | json_pp 2>/dev/null || curl -s -X GET "${BASE_URL}/reports/trial-balance?tenant_id=${TENANT_ID}"
echo ""
echo ""

# Test 8: AP Aging (existing endpoint)
echo "8. Testing AP Aging API (Existing)..."
echo "URL: ${BASE_URL}/reports/aging/ap?tenant_id=${TENANT_ID}"
curl -s -X GET "${BASE_URL}/reports/aging/ap?tenant_id=${TENANT_ID}" | json_pp 2>/dev/null || curl -s -X GET "${BASE_URL}/reports/aging/ap?tenant_id=${TENANT_ID}"
echo ""
echo ""

# Test 9: AR Aging (existing endpoint)
echo "9. Testing AR Aging API (Existing)..."
echo "URL: ${BASE_URL}/reports/aging/ar?tenant_id=${TENANT_ID}"
curl -s -X GET "${BASE_URL}/reports/aging/ar?tenant_id=${TENANT_ID}" | json_pp 2>/dev/null || curl -s -X GET "${BASE_URL}/reports/aging/ar?tenant_id=${TENANT_ID}"
echo ""
echo ""

echo "=========================================="
echo "Test Suite Complete!"
echo "=========================================="
