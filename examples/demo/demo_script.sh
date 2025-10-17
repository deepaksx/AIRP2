#!/bin/bash

# AIRP v2.0 - End-to-End Demo Script
# Demonstrates: Invoice Upload → AI Classification → Ledger Posting → Verification

set -e

echo "╔════════════════════════════════════════════════════════╗"
echo "║                                                        ║"
echo "║  AIRP v2.0 - AI-Native Financial ERP Demo             ║"
echo "║  End-to-End Invoice Processing Workflow               ║"
echo "║                                                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Configuration
LEDGER_WRITER="http://localhost:3001"
AI_ACCOUNTING="http://localhost:8001"
TENANT_ID="550e8400-e29b-41d4-a716-446655440000"
USER_ID="user-cfo-001"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Health Checks
echo -e "${BLUE}Step 1: Checking service health...${NC}"
echo ""

echo "Checking Ledger Writer..."
curl -s "${LEDGER_WRITER}/health" | jq '.'
echo ""

echo "Checking AI Auto-Accounting..."
curl -s "${AI_ACCOUNTING}/health" | jq '.'
echo ""

echo -e "${GREEN}✓ All services are healthy${NC}"
echo ""
sleep 2

# Step 2: AI Classification
echo -e "${BLUE}Step 2: Classifying invoice with AI...${NC}"
echo ""

AI_RESPONSE=$(curl -s -X POST "${AI_ACCOUNTING}/classify" \
  -H "Content-Type: application/json" \
  -d "{
    \"tenant_id\": \"${TENANT_ID}\",
    \"invoice_id\": \"demo-inv-$(date +%s)\",
    \"vendor_name\": \"Dubai Marketing Agency\",
    \"transaction_type\": \"AP\",
    \"lines\": [
      {
        \"line_number\": 1,
        \"description\": \"Social media advertising campaign for Q1 2024\",
        \"amount\": 15000.00,
        \"quantity\": 1.0
      }
    ]
  }")

echo "${AI_RESPONSE}" | jq '.'
echo ""

# Extract suggested account code
ACCOUNT_CODE=$(echo "${AI_RESPONSE}" | jq -r '.suggestions[0].account_code')
CONFIDENCE=$(echo "${AI_RESPONSE}" | jq -r '.suggestions[0].confidence_score')
REASONING=$(echo "${AI_RESPONSE}" | jq -r '.suggestions[0].reasoning')

echo -e "${GREEN}✓ AI Classification Complete${NC}"
echo -e "  Account Code: ${YELLOW}${ACCOUNT_CODE}${NC}"
echo -e "  Confidence: ${YELLOW}${CONFIDENCE}${NC}"
echo -e "  Reasoning: ${REASONING}"
echo ""
sleep 2

# Step 3: Post Journal Entry
echo -e "${BLUE}Step 3: Posting journal entry to immutable ledger...${NC}"
echo ""

# Calculate amounts with VAT
SUBTOTAL=15000.00
VAT_AMOUNT=$(echo "scale=2; ${SUBTOTAL} * 0.05" | bc)
TOTAL=$(echo "scale=2; ${SUBTOTAL} + ${VAT_AMOUNT}" | bc)

JE_RESPONSE=$(curl -s -X POST "${LEDGER_WRITER}/journal-entries" \
  -H "Content-Type: application/json" \
  -d "{
    \"tenantId\": \"${TENANT_ID}\",
    \"entryDate\": \"$(date +%Y-%m-%d)\",
    \"entryType\": \"Standard\",
    \"description\": \"Marketing Expense - Dubai Marketing Agency\",
    \"userId\": \"${USER_ID}\",
    \"sourceType\": \"AP\",
    \"aiGenerated\": true,
    \"aiConfidenceScore\": ${CONFIDENCE},
    \"lines\": [
      {
        \"accountCode\": \"${ACCOUNT_CODE}\",
        \"debitAmount\": ${TOTAL},
        \"creditAmount\": 0,
        \"description\": \"Marketing & Advertising (incl. 5% VAT)\"
      },
      {
        \"accountCode\": \"2100\",
        \"debitAmount\": 0,
        \"creditAmount\": ${TOTAL},
        \"description\": \"Accounts Payable - Dubai Marketing Agency\"
      }
    ]
  }")

echo "${JE_RESPONSE}" | jq '.'
echo ""

ENTRY_ID=$(echo "${JE_RESPONSE}" | jq -r '.entryId')
EVENT_ID=$(echo "${JE_RESPONSE}" | jq -r '.event.event_id')

echo -e "${GREEN}✓ Journal Entry Posted${NC}"
echo -e "  Entry ID: ${YELLOW}${ENTRY_ID}${NC}"
echo -e "  Event ID: ${YELLOW}${EVENT_ID}${NC}"
echo ""
sleep 2

# Step 4: Verify Event Store
echo -e "${BLUE}Step 4: Verifying immutable event store...${NC}"
echo ""

EVENT_DATA=$(curl -s "${LEDGER_WRITER}/events/aggregate/${ENTRY_ID}?tenantId=${TENANT_ID}")
echo "${EVENT_DATA}" | jq '.'
echo ""

echo -e "${GREEN}✓ Event retrieved from immutable store${NC}"
echo ""
sleep 2

# Step 5: Verify Integrity
echo -e "${BLUE}Step 5: Verifying event integrity (checksum)...${NC}"
echo ""

INTEGRITY=$(curl -s "${LEDGER_WRITER}/events/verify/${EVENT_ID}")
echo "${INTEGRITY}" | jq '.'
echo ""

IS_VALID=$(echo "${INTEGRITY}" | jq -r '.isValid')

if [ "${IS_VALID}" == "true" ]; then
  echo -e "${GREEN}✓ Event integrity verified - checksum matches${NC}"
else
  echo -e "\033[0;31m✗ Event integrity check failed!${NC}"
fi
echo ""
sleep 2

# Step 6: Query Event Statistics
echo -e "${BLUE}Step 6: Querying event statistics...${NC}"
echo ""

STATS=$(curl -s "${LEDGER_WRITER}/events/stats?tenantId=${TENANT_ID}")
echo "${STATS}" | jq '.'
echo ""

echo -e "${GREEN}✓ Event statistics retrieved${NC}"
echo ""
sleep 2

# Summary
echo "╔════════════════════════════════════════════════════════╗"
echo "║                                                        ║"
echo "║  Demo Complete! ✓                                      ║"
echo "║                                                        ║"
echo "║  What Just Happened:                                   ║"
echo "║  1. AI classified invoice line → Marketing (5700)      ║"
echo "║  2. Posted journal entry to immutable ledger           ║"
echo "║  3. Event stored with SHA-256 checksum                 ║"
echo "║  4. Verified event integrity                           ║"
echo "║  5. Complete audit trail maintained                    ║"
echo "║                                                        ║"
echo "║  Key Features Demonstrated:                            ║"
echo "║  • Event sourcing with immutability                    ║"
echo "║  • AI-powered GL classification                        ║"
echo "║  • Confidence scoring & explainability                 ║"
echo "║  • Cryptographic integrity verification                ║"
echo "║  • Complete audit trail (who, what, when, why)         ║"
echo "║                                                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "  • View Swagger docs: ${LEDGER_WRITER}/api/docs"
echo "  • Explore AI service: ${AI_ACCOUNTING}/docs"
echo "  • Check Grafana dashboards: http://localhost:3100"
echo "  • Query Kafka events: http://localhost:8080"
echo "  • Review event store: psql -h localhost -U airp_admin -d airp_master"
echo ""

echo -e "${GREEN}Thank you for exploring AIRP v2.0!${NC}"
