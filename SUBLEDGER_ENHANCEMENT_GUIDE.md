# Sub-Ledger Accounting - Enhancement Guide

## Overview

Sub-ledgers track detailed transactions for control accounts:
- **AP Sub-Ledger** → Control Account 2100 (Accounts Payable)
- **AR Sub-Ledger** → Control Account 1200 (Accounts Receivable)

## Database Design

### journal_entry_lines Table
```sql
CREATE TABLE journal_entry_lines (
  line_id UUID PRIMARY KEY,
  entry_id UUID NOT NULL,
  account_id UUID NOT NULL,
  debit_amount NUMERIC(20,4),
  credit_amount NUMERIC(20,4),

  -- Sub-Ledger Dimensions
  dimension_1 VARCHAR(50),  -- Vendor ID (for AP)
  dimension_2 VARCHAR(50),  -- Customer ID (for AR)
  dimension_3 VARCHAR(50),  -- Project / Cost Center
  dimension_4 VARCHAR(50),  -- Department / Location

  -- Flexible metadata
  metadata JSONB
);
```

## Use Cases

### 1. Vendor Invoice (AP)
**Scenario:** Rent invoice from Dubai Properties LLC (15,000 AED)

**Journal Entry:**
```
DR  5300 - Rent Expense         15,000
    CR  2100 - Accounts Payable        15,000 [Vendor: Dubai Properties]
```

**API Payload:**
```json
{
  "tenantId": "00000000-0000-0000-0000-000000000001",
  "entryDate": "2025-01-15",
  "description": "Office rent January 2025 - Dubai Properties LLC",
  "lines": [
    {
      "lineNumber": 1,
      "accountCode": "5300",
      "debitAmount": 15000,
      "creditAmount": 0,
      "description": "Rent Expense"
    },
    {
      "lineNumber": 2,
      "accountCode": "2100",
      "debitAmount": 0,
      "creditAmount": 15000,
      "description": "Accounts Payable",
      "dimension_1": "10000000-0000-0000-0000-000000000001",
      "metadata": {
        "vendor_name": "Dubai Properties LLC",
        "invoice_number": "INV-2025-001",
        "due_date": "2025-02-14"
      }
    }
  ]
}
```

### 2. Customer Invoice (AR)
**Scenario:** Invoice to Acme Corp (50,000 AED)

**Journal Entry:**
```
DR  1200 - Accounts Receivable  50,000 [Customer: Acme Corp]
    CR  4000 - Revenue                  50,000
```

**API Payload:**
```json
{
  "lines": [
    {
      "lineNumber": 1,
      "accountCode": "1200",
      "debitAmount": 50000,
      "creditAmount": 0,
      "dimension_2": "customer-uuid-acme-corp",
      "metadata": {
        "customer_name": "Acme Corp",
        "invoice_number": "SI-2025-001"
      }
    },
    {
      "lineNumber": 2,
      "accountCode": "4000",
      "debitAmount": 0,
      "creditAmount": 50000
    }
  ]
}
```

### 3. Vendor Payment
**Scenario:** Pay Dubai Properties LLC (15,000 AED)

**Journal Entry:**
```
DR  2100 - Accounts Payable     15,000 [Vendor: Dubai Properties]
    CR  1000 - Cash                     15,000
```

**API Payload:**
```json
{
  "lines": [
    {
      "lineNumber": 1,
      "accountCode": "2100",
      "debitAmount": 15000,
      "creditAmount": 0,
      "dimension_1": "10000000-0000-0000-0000-000000000001",
      "metadata": {
        "vendor_name": "Dubai Properties LLC",
        "payment_method": "Bank Transfer",
        "reference": "PMT-2025-001"
      }
    },
    {
      "lineNumber": 2,
      "accountCode": "1000",
      "debitAmount": 0,
      "creditAmount": 15000
    }
  ]
}
```

### 4. Multi-Dimensional Entry
**Scenario:** Rent for Project Alpha, Dubai Office (15,000 AED)

**API Payload:**
```json
{
  "lines": [
    {
      "lineNumber": 1,
      "accountCode": "5300",
      "debitAmount": 15000,
      "creditAmount": 0,
      "dimension_3": "project-alpha",       // Project
      "dimension_4": "dubai-office",        // Location
      "metadata": {
        "cost_center": "CC-001",
        "department": "Operations"
      }
    },
    {
      "lineNumber": 2,
      "accountCode": "2100",
      "debitAmount": 0,
      "creditAmount": 15000,
      "dimension_1": "vendor-dubai-properties"  // Vendor
    }
  ]
}
```

## Reporting Queries

### Vendor Ledger Report
```sql
SELECT
  je.entry_date,
  je.entry_number,
  je.description,
  jel.debit_amount,
  jel.credit_amount,
  jel.metadata->>'invoice_number' AS invoice_number
FROM journal_entry_lines jel
JOIN journal_entries je ON jel.entry_id = je.entry_id
WHERE jel.dimension_1 = 'vendor-uuid'
  AND jel.account_id = (SELECT account_id FROM chart_of_accounts WHERE account_code = '2100')
ORDER BY je.entry_date;
```

**Result:**
| Date | Entry# | Description | Debit | Credit | Invoice# |
|------|--------|-------------|-------|--------|----------|
| 2025-01-15 | JE-001 | Rent invoice | 0 | 15,000 | INV-2025-001 |
| 2025-02-14 | JE-015 | Payment | 15,000 | 0 | PMT-2025-001 |
| | | **Balance** | **15,000** | **15,000** | **0** |

### Customer Ledger Report
```sql
SELECT
  je.entry_date,
  je.entry_number,
  je.description,
  jel.debit_amount,
  jel.credit_amount
FROM journal_entry_lines jel
JOIN journal_entries je ON jel.entry_id = je.entry_id
WHERE jel.dimension_2 = 'customer-uuid'
  AND jel.account_id = (SELECT account_id FROM chart_of_accounts WHERE account_code = '1200')
ORDER BY je.entry_date;
```

### Trial Balance (GL Control Accounts)
```sql
SELECT
  coa.account_code,
  coa.account_name,
  SUM(jel.debit_amount) AS total_debits,
  SUM(jel.credit_amount) AS total_credits
FROM journal_entry_lines jel
JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
GROUP BY coa.account_code, coa.account_name
ORDER BY coa.account_code;
```

## Enhanced JE Form Wireframe

```
╔══════════════════════════════════════════════════════════════╗
║  Journal Entry - Line Details                                 ║
╠══════════════════════════════════════════════════════════════╣
║  Account Code: [2100 ▼] Accounts Payable                     ║
║  Description:  [Invoice from vendor]                          ║
║  Debit:        [    0.00]  Credit: [15,000.00]               ║
║                                                               ║
║  ┌─ Sub-Ledger Details ────────────────────────────────────┐ ║
║  │ ☑ This line relates to:                                 │ ║
║  │   ○ Vendor    [ Dubai Properties LLC ▼ ]                │ ║
║  │   ○ Customer  [ Select customer...   ▼ ]                │ ║
║  │   ○ Project   [ Select project...    ▼ ]                │ ║
║  │   ○ Location  [ Dubai Office         ▼ ]                │ ║
║  │                                                          │ ║
║  │ Additional Info:                                         │ ║
║  │   Invoice#:   [INV-2025-001]                            │ ║
║  │   Due Date:   [2025-02-14]                              │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  [Add Line] [Remove Line]                                     ║
╚══════════════════════════════════════════════════════════════╝
```

## Implementation Checklist

### Backend (Already Done ✅)
- [x] journal_entry_lines table has dimension columns
- [x] journal_entry_lines table has metadata JSONB column
- [x] Vendor master data API (GET /vendors)
- [x] Customer master data API (GET /customers)
- [x] Vendor Ledger report API (GET /reports/vendor-ledger)
- [x] Customer Ledger report API (GET /reports/customer-ledger)

### Frontend (To Enhance)
- [ ] Add vendor dropdown to JE line items
- [ ] Add customer dropdown to JE line items
- [ ] Show vendor/customer selector only for AP/AR accounts
- [ ] Load vendors from API when account 2100 selected
- [ ] Load customers from API when account 1200 selected
- [ ] Include dimension_1/dimension_2 in payload
- [ ] Add metadata fields (invoice#, due date)

### Auto-Detection Rules
```javascript
// When user selects account 2100 (AP)
if (accountCode === '2100') {
  showVendorSelector = true;
  loadVendors();
}

// When user selects account 1200 (AR)
if (accountCode === '1200') {
  showCustomerSelector = true;
  loadCustomers();
}

// When posting
payload.lines[i].dimension_1 = selectedVendorId;  // If AP line
payload.lines[i].dimension_2 = selectedCustomerId; // If AR line
```

## Benefits

✅ **Track specific vendors/customers** - Know exactly who you owe/who owes you
✅ **Aged AP/AR reports** - See overdue invoices per vendor/customer
✅ **Vendor/Customer statements** - Print detailed transaction history
✅ **Project costing** - Track expenses by project using dimension_3
✅ **Multi-dimensional analysis** - Analyze by vendor, project, location, etc.
✅ **Reconciliation** - Match payments to invoices using metadata

## Example: Full Vendor Cycle

**Step 1: Receive Invoice**
```
DR  5300 - Rent             15,000
    CR  2100 - AP (Vendor)         15,000
```

**Step 2: Make Payment**
```
DR  2100 - AP (Vendor)      15,000
    CR  1000 - Cash                15,000
```

**Vendor Ledger:**
| Date | Description | Debit | Credit | Balance |
|------|-------------|-------|--------|---------|
| 01/15 | Invoice | 0 | 15,000 | 15,000 CR |
| 02/14 | Payment | 15,000 | 0 | 0 |

**GL Account 2100:**
| Date | Description | Debit | Credit | Balance |
|------|-------------|-------|--------|---------|
| 01/15 | All vendors invoices | 0 | 45,000 | 45,000 CR |
| 02/14 | All vendors payments | 15,000 | 0 | 30,000 CR |

✅ **Reconciliation:** Sum of all vendor ledgers = GL account 2100 balance

## Next Steps

1. ✅ Database schema supports sub-ledgers (dimension columns exist)
2. ✅ Backend APIs ready (vendors, customers, reports)
3. 🔲 Enhance JE form to include vendor/customer selection
4. 🔲 Test end-to-end flow with vendor transaction
5. 🔲 Generate vendor ledger report
6. 🔲 Verify GL 2100 balance = sum of vendor balances

