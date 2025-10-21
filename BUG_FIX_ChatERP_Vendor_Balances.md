# BUG FIX: ChatERP Showing Incorrect Vendor Balances

**Date**: October 21, 2025
**Severity**: HIGH
**Impact**: ChatERP displays incorrect vendor balances (1,050 AED instead of 353,557.05 AED)

---

## Problem Description

### User Report

User asked: "Are they same?" comparing two screenshots:

**Image #1 - Vendor Ledger Report** (CORRECT ✅):
- ABC Stationery LLC: 44,971.50 AED
- Test Vendor Inc: 61,049.10 AED
- Global Supplies Company LLC: 49,282.80 AED
- Office Supplies LLC: 49,763.70 AED
- IT Solutions Inc: 70,543.20 AED
- Cleaning Services Co: 77,946.75 AED
- **Total AP (Sub-Ledger): 353,557.05 AED**

**Image #2 - ChatERP** (WRONG ❌):
- Test Vendor Inc: 1,050.00 AED (1 invoice)
- All others: 0.00 AED (0 invoices)
- **Total Payable: 1,050.00 AED**

---

## Root Cause Analysis

### Investigation Steps

1. **Checked Database** - Found 6 vendors in `vendors` table ✅
2. **Checked AP Invoices Table** - Found only 1 invoice (TEST-AP-001) ❌
3. **Checked GL (Journal Entries)** - Found 42 invoices across all vendors ✅
4. **Checked Vendor Dimensions** - ALL GL entries have proper vendor tracking (dimension_1) ✅

### The Real Problem

**ChatERP is querying the WRONG data source:**

❌ **Current (Incorrect)**: Queries `ap_invoices` table
```sql
SELECT v.vendor_name, COALESCE(SUM(i.amount_outstanding), 0) as balance
FROM vendors v
LEFT JOIN ap_invoices i ON v.vendor_id = i.vendor_id
WHERE v.tenant_id = ?
GROUP BY v.vendor_id
```

✅ **Should Be (Correct)**: Queries GL (journal_entry_lines with dimension_1)
```sql
SELECT v.vendor_name, COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) as balance
FROM vendors v
LEFT JOIN journal_entry_lines jel ON jel.dimension_1::text = v.vendor_id::text
LEFT JOIN journal_entries je ON jel.entry_id = je.entry_id
LEFT JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
WHERE v.tenant_id = ?
  AND coa.account_code = '2100'
  AND je.status = 'posted'
GROUP BY v.vendor_id, v.vendor_name
```

---

## Why This Happened

### Historical Context

The system has 42 AP invoices (INV-AP-2025-0001 through INV-AP-2025-0042) that were:

✅ **Posted to GL** with proper journal entries
✅ **Tracked with vendor dimensions** (dimension_1 = vendor_id)
❌ **NOT created in ap_invoices table** (only TEST-AP-001 exists there)

### Data Verification

**GL Query Result** (Source of Truth):
```
ABC-STAT-001: 44,971.50 AED
V001: 61,049.10 AED
V002: 49,282.80 AED
VEN001: 49,763.70 AED
VEN002: 70,543.20 AED
VEN003: 77,946.75 AED
TOTAL: 353,557.05 AED
```

**AP Invoices Table Result** (Incomplete):
```
ABC-STAT-001: 0.00 AED
V001: 1,050.00 AED  ← Only TEST-AP-001
V002: 0.00 AED
VEN001: 0.00 AED
VEN002: 0.00 AED
VEN003: 0.00 AED
TOTAL: 1,050.00 AED
```

**Reconciliation Check**:
- GL Account 2100 Balance: 353,557.05 AED ✅
- Trial Balance shows BALANCED (0.00 variance) ✅
- Vendor Ledger Report matches GL ✅
- ChatERP does NOT match ❌

---

## The Fix

### File to Modify

**File**: `services/ai-query-parser/app/main.py`
**Line**: 173

### Current Code (Line 173)

```python
"sql_query": "SELECT v.vendor_name, COALESCE(SUM(i.amount_outstanding), 0) as balance FROM vendors v LEFT JOIN ap_invoices i ON v.vendor_id = i.vendor_id WHERE v.tenant_id = ? GROUP BY v.vendor_id HAVING balance > 5000 ORDER BY balance DESC",
```

### Fixed Code

```python
"sql_query": "SELECT v.vendor_code, v.vendor_name, COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) as balance FROM vendors v LEFT JOIN journal_entry_lines jel ON jel.dimension_1::text = v.vendor_id::text LEFT JOIN journal_entries je ON jel.entry_id = je.entry_id LEFT JOIN chart_of_accounts coa ON jel.account_id = coa.account_id WHERE v.tenant_id = ? AND (coa.account_code = '2100' OR coa.account_code IS NULL) AND (je.status = 'posted' OR je.status IS NULL) GROUP BY v.vendor_id, v.vendor_code, v.vendor_name HAVING balance > 5000 ORDER BY balance DESC",
```

### Additional Changes Needed

The AI Query Parser has this query hardcoded as an **example** in the prompt. The Claude AI model learns from this example and generates similar queries. We need to:

1. **Update the example query** (line 173)
2. **Add documentation** explaining vendor balances MUST come from GL
3. **Update database_schema.txt** with vendor balance query patterns
4. **Restart the service** to reload the updated prompt

---

## Implementation Steps

### Step 1: Update Main.py

```bash
# Stop the service
docker compose stop ai-query-parser

# Edit the file
# (Manual edit required - file is locked by Docker volume mount)

# Restart the service
docker compose start ai-query-parser
```

### Step 2: Update database_schema.txt

Add to `services/ai-query-parser/database_schema.txt`:

```
═══════════════════════════════════════════════════════════════════════════════
VENDOR BALANCE QUERIES - CRITICAL RULES
═══════════════════════════════════════════════════════════════════════════════

❌ NEVER query ap_invoices table for vendor balances!

✅ ALWAYS query GL (journal_entry_lines) with dimension_1 = vendor_id

CORRECT PATTERN:
SELECT
  v.vendor_code,
  v.vendor_name,
  COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) as balance
FROM vendors v
LEFT JOIN journal_entry_lines jel ON jel.dimension_1::text = v.vendor_id::text
LEFT JOIN journal_entries je ON jel.entry_id = je.entry_id
LEFT JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
WHERE v.tenant_id = ?
  AND coa.account_code = '2100'  -- Accounts Payable
  AND je.status = 'posted'
GROUP BY v.vendor_id, v.vendor_code, v.vendor_name
ORDER BY v.vendor_code

REASON:
- GL is the source of truth (event-sourced)
- ap_invoices table may be incomplete (historical data)
- dimension_1 tracks vendor on GL entries
- Account 2100 is Accounts Payable control account
```

### Step 3: Test the Fix

```bash
# Test query directly
curl -s -X POST http://localhost:3008/api/query \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"SELECT v.vendor_code, v.vendor_name, COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) as balance FROM vendors v LEFT JOIN journal_entry_lines jel ON jel.dimension_1::text = v.vendor_id::text LEFT JOIN journal_entries je ON jel.entry_id = je.entry_id LEFT JOIN chart_of_accounts coa ON jel.account_id = coa.account_id WHERE v.tenant_id = '00000000-0000-0000-0000-000000000001' AND coa.account_code = '2100' AND je.status = 'posted' GROUP BY v.vendor_id, v.vendor_code, v.vendor_name ORDER BY v.vendor_code\"}"

# Expected result: 353,557.05 AED total
```

### Step 4: Test ChatERP

```
1. Open http://localhost:5000
2. Click AI ASSISTANT → ChatERP
3. Ask: "List vendor balances"
4. Verify: Should show 353,557.05 AED total (not 1,050.00)
```

---

## Verification Checklist

- [ ] AI Query Parser main.py updated (line 173)
- [ ] database_schema.txt updated with vendor balance rules
- [ ] Service restarted: `docker compose restart ai-query-parser`
- [ ] Direct query test returns 353,557.05 AED
- [ ] ChatERP shows correct balances
- [ ] Vendor Ledger still works (no regression)
- [ ] Git commit created with bug fix

---

## Prevention Measures

### For Future Development

1. **Never use ap_invoices for balances** - It's not the source of truth
2. **Always use GL (journal_entry_lines)** - Event-sourced, immutable, complete
3. **Check dimension_1 for vendor tracking** - Mandatory for AP entries
4. **Use account_code = '2100'** - Accounts Payable control account
5. **Test against Vendor Ledger report** - Should match exactly

### Documentation Updates

1. Add to ACCOUNTING_PROTOCOLS.md:
   ```
   ## Data Source Hierarchy

   1. **General Ledger** (journal_entries + journal_entry_lines) - Source of Truth
   2. **Materialized Views** (trial_balance, gl_balances) - Performance
   3. **Sub-Ledgers** (ap_invoices, ar_invoices) - May be incomplete

   RULE: For balances and reports, ALWAYS query GL first.
   ```

2. Add to AI_SERVICES_USER_MANUAL.md:
   ```
   ## ChatERP Query Patterns

   Vendor Balances:
   - Query: "List vendor balances" or "Show accounts payable"
   - Data Source: GL (journal_entry_lines with dimension_1)
   - Expected: Matches Vendor Ledger report exactly
   ```

---

## Impact Analysis

### Systems Affected

- ✅ **Vendor Ledger Report** - Already correct (uses GL)
- ❌ **ChatERP** - Shows wrong data (uses ap_invoices)
- ✅ **Trial Balance** - Correct (uses GL)
- ✅ **AP Aging Report** - Need to verify data source
- ✅ **GL Account 2100 Report** - Correct (uses GL)

### User Impact

**Before Fix**:
- Users see incorrect balances in ChatERP
- Total shows 1,050.00 AED instead of 353,557.05 AED
- 5 out of 6 vendors show 0.00 balance incorrectly
- Loss of trust in AI assistant

**After Fix**:
- ChatERP matches Vendor Ledger exactly
- Total shows correct 353,557.05 AED
- All 6 vendors show accurate balances
- Consistent data across all interfaces

---

## Testing Script

```powershell
# Test 1: Direct GL Query (Should return 353,557.05)
$query1 = @{
    query = "SELECT COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) as total_ap FROM journal_entry_lines jel JOIN journal_entries je ON jel.entry_id = je.entry_id JOIN chart_of_accounts coa ON jel.account_id = coa.account_id WHERE je.tenant_id = '00000000-0000-0000-0000-000000000001' AND coa.account_code = '2100' AND je.status = 'posted'"
} | ConvertTo-Json
curl -s -X POST http://localhost:3008/api/query -H "Content-Type: application/json" -d $query1

# Test 2: Vendor Breakdown (Should show all 6 vendors)
$query2 = @{
    query = "SELECT v.vendor_code, v.vendor_name, COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) as balance FROM vendors v LEFT JOIN journal_entry_lines jel ON jel.dimension_1::text = v.vendor_id::text LEFT JOIN journal_entries je ON jel.entry_id = je.entry_id LEFT JOIN chart_of_accounts coa ON jel.account_id = coa.account_id WHERE v.tenant_id = '00000000-0000-0000-0000-000000000001' AND coa.account_code = '2100' AND je.status = 'posted' GROUP BY v.vendor_id, v.vendor_code, v.vendor_name ORDER BY v.vendor_code"
} | ConvertTo-Json
curl -s -X POST http://localhost:3008/api/query -H "Content-Type: application/json" -d $query2

# Test 3: ChatERP Query
# Manual: Open ChatERP and ask "List vendor balances"
# Expected: Should match test 2 results
```

---

## Summary

### Issue
ChatERP shows incorrect vendor balances (1,050 AED) because it queries the incomplete `ap_invoices` table instead of the authoritative GL (journal_entry_lines).

### Fix
Update AI Query Parser to use GL as the data source for vendor balances, matching the Vendor Ledger report implementation.

### Files to Change
1. `services/ai-query-parser/app/main.py` (line 173)
2. `services/ai-query-parser/database_schema.txt` (add vendor balance rules)

### Expected Result
ChatERP will show correct vendor balances (353,557.05 AED total) matching the Vendor Ledger report.

---

**Status**: Ready for Implementation
**Priority**: HIGH (Data Accuracy Issue)
**Estimated Time**: 15 minutes
**Risk**: LOW (Isolated to AI Query Parser prompt examples)
