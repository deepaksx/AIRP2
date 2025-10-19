# Journal Entry First Architecture - AIRP v2.5

## Executive Summary

**Principle**: Journal Entry (JE) is the **single source of truth** for all financial transactions.

All financial postings—whether AP invoices, AR invoices, payments, or general entries—MUST flow through the Journal Entry module. Sub-ledgers (AP, AR, Projects, Cost Centers) are **projections/views** of the General Ledger, not independent systems.

---

## Why JE-First Architecture?

### 1. Accounting Best Practice
- **GAAP/IFRS Compliance**: Financial statements are built from the General Ledger
- **Single Source of Truth**: Eliminates data synchronization issues
- **Audit Trail**: Complete, immutable event log in one place
- **No Reconciliation Issues**: Sub-ledgers are calculated from GL, not stored separately

### 2. Current Problem with Dual Systems

**Old Architecture (WRONG)**:
```
AP Service                    Ledger Writer
    │                              │
    ├─> ap_invoices table         │
    │                              │
    └─> Kafka Event ──────────────> journal_entries
            ↓
    (Can fail, delay, or get out of sync)
```

**Issues**:
- Two sources of truth (ap_invoices vs journal_entries)
- Data can be out of sync if Kafka fails
- Projection service delay causes timing mismatch
- Need reconciliation between ap_invoices and GL
- Variance possible (we saw 371,812 AED variance before)

### 3. Correct Architecture

**JE-First Architecture (CORRECT)**:
```
Journal Entry Module (Single Entry Point)
    │
    └─> journal_entries (event_store)
            │
            ├─> CQRS Projections
            │       ├─> gl_balances
            │       ├─> trial_balance (materialized view)
            │       └─> account_balances
            │
            └─> Sub-Ledger Views (calculated from JE dimensions)
                    ├─> Vendor Ledger (dimension_1 = vendor_id)
                    ├─> Customer Ledger (dimension_2 = customer_id)
                    ├─> Project Ledger (dimension_3 = project_id)
                    └─> Cost Center Ledger (dimension_4 = cost_center_id)
```

**Benefits**:
- ✅ Single source of truth
- ✅ No synchronization issues
- ✅ No reconciliation needed (sub-ledgers are GL views)
- ✅ Perfect data integrity
- ✅ Real-time consistency

---

## Implementation Plan

### Phase 1: Enhanced JE Module ✅ (Completed)

**File**: `post-je-enhanced.html`

**Features**:
1. **Transaction Type Selector**:
   - AP Invoice
   - AR Invoice
   - Payment (Vendor/Customer)
   - Bank Transaction
   - General Entry
   - Depreciation
   - (Future: Payroll, Fixed Asset Purchase, Inventory, etc.)

2. **Dynamic Form Fields**:
   - Based on transaction type, show/hide:
     - Vendor selection (for AP)
     - Customer selection (for AR)
     - Project selection (optional)
     - Cost Center selection (optional)

3. **Enforced Controls**:
   - Vendor REQUIRED when posting to account 2100 (AP)
   - Customer REQUIRED when posting to account 1200 (AR)
   - Double-entry validation (debits = credits)

4. **User Experience**:
   - Visual transaction type cards
   - Auto-populated templates based on type
   - Real-time balance calculation
   - Clear error messages

### Phase 2: Deprecate Direct AP/AR Posting ⚠️ (Required)

**Action Items**:

1. **Disable AP Service Invoice Endpoint**:
   ```typescript
   // services/ap-service/src/invoices/invoices.controller.ts
   @Post()
   async create() {
     throw new HttpException(
       'Direct AP posting is disabled. Please use Journal Entry module.',
       HttpStatus.METHOD_NOT_ALLOWED
     );
   }
   ```

2. **Disable AR Service Invoice Endpoint**:
   ```typescript
   // services/ar-service/src/invoices/invoices.controller.ts
   @Post()
   async create() {
     throw new HttpException(
       'Direct AR posting is disabled. Please use Journal Entry module.',
       HttpStatus.METHOD_NOT_ALLOWED
     );
   }
   ```

3. **Update Documentation**:
   - Update API docs to show JE module as primary entry point
   - Add migration guide for existing integrations
   - Document transaction type mapping

### Phase 3: Sub-Ledger Reports from GL Dimensions ✅ (Completed)

**Already Implemented**:
- `vendor-ledger.html`: Queries `journal_entry_lines` via `dimension_1`
- `customer-ledger.html`: Queries `journal_entry_lines` via `dimension_2`

**Future Enhancements**:
- Project Ledger (dimension_3)
- Cost Center Ledger (dimension_4)
- Multi-dimensional reporting (e.g., Project + Cost Center)

### Phase 4: Drop ap_invoices and ar_invoices Tables 🗑️ (Future)

**After migration is complete**:

1. **Verify all data is in GL**:
   ```sql
   -- Count orphaned records
   SELECT COUNT(*) FROM ap_invoices WHERE invoice_id NOT IN (
     SELECT DISTINCT metadata->>'source_invoice_id' FROM journal_entries
   );
   ```

2. **Drop tables**:
   ```sql
   DROP TABLE ap_invoice_lines;
   DROP TABLE ap_invoices;
   DROP TABLE ar_invoice_lines;
   DROP TABLE ar_invoices;
   ```

3. **Benefits**:
   - Simplified schema
   - No dual storage
   - Reduced storage costs
   - Faster queries (no JOINs needed)

---

## Transaction Type Templates

### 1. AP Invoice
```json
{
  "entryType": "ap_invoice",
  "lines": [
    {
      "accountCode": "5100",
      "debitAmount": 1000,
      "creditAmount": 0,
      "description": "Expense - Office supplies"
    },
    {
      "accountCode": "2130",
      "debitAmount": 50,
      "creditAmount": 0,
      "description": "VAT - 5%"
    },
    {
      "accountCode": "2100",
      "debitAmount": 0,
      "creditAmount": 1050,
      "description": "AP - Vendor XYZ",
      "vendorId": "uuid-here",
      "invoiceNumber": "INV-001",
      "dueDate": "2025-11-18"
    }
  ]
}
```

### 2. AR Invoice
```json
{
  "entryType": "ar_invoice",
  "lines": [
    {
      "accountCode": "1200",
      "debitAmount": 2100,
      "creditAmount": 0,
      "description": "AR - Customer ABC",
      "customerId": "uuid-here",
      "invoiceNumber": "SI-001",
      "dueDate": "2025-11-18"
    },
    {
      "accountCode": "4000",
      "debitAmount": 0,
      "creditAmount": 2000,
      "description": "Revenue - Product sales"
    },
    {
      "accountCode": "2130",
      "debitAmount": 0,
      "creditAmount": 100,
      "description": "VAT - 5%"
    }
  ]
}
```

### 3. Vendor Payment
```json
{
  "entryType": "payment",
  "lines": [
    {
      "accountCode": "2100",
      "debitAmount": 1050,
      "creditAmount": 0,
      "description": "Payment to Vendor XYZ",
      "vendorId": "uuid-here",
      "invoiceNumber": "INV-001"
    },
    {
      "accountCode": "1000",
      "debitAmount": 0,
      "creditAmount": 1050,
      "description": "Cash payment"
    }
  ]
}
```

### 4. Customer Receipt
```json
{
  "entryType": "receipt",
  "lines": [
    {
      "accountCode": "1000",
      "debitAmount": 2100,
      "creditAmount": 0,
      "description": "Cash received"
    },
    {
      "accountCode": "1200",
      "debitAmount": 0,
      "creditAmount": 2100,
      "description": "Payment from Customer ABC",
      "customerId": "uuid-here",
      "invoiceNumber": "SI-001"
    }
  ]
}
```

---

## Data Flow

### Traditional Flow (OLD - Being Deprecated):
```
User → AP Service → ap_invoices table
                       ↓
                   Kafka Event
                       ↓
            Projection Service
                       ↓
              Journal Entry API
                       ↓
              journal_entries
```

**Problems**: Multiple hops, async delays, potential failures

### JE-First Flow (NEW - Recommended):
```
User → Journal Entry Module → journal_entries (event_store)
                                      ↓
                           CQRS Projections
                                      ↓
                    ┌─────────────────┴─────────────────┐
                    ↓                                   ↓
              gl_balances                    Sub-Ledger Views
         (materialized view)              (calculated from dimensions)
```

**Benefits**: Single hop, synchronous, guaranteed consistency

---

## Accounting Controls Enforced

### 1. Double-Entry Bookkeeping
```typescript
if (Math.abs(totalDebits - totalCredits) > 0.01) {
  throw new Error('Entry is not balanced');
}
```

### 2. AR/AP Control Account Protection (v2.4.0)
```typescript
if (accountCode === '2100' && !vendorId) {
  throw new Error('Account 2100 (AP) requires Vendor ID');
}

if (accountCode === '1200' && !customerId) {
  throw new Error('Account 1200 (AR) requires Customer ID');
}
```

### 3. Immutability
- Posted entries cannot be edited
- Corrections via reversing entries only
- Complete audit trail in event_store

### 4. Segregation of Duties (Future)
- Creator ≠ Approver
- Workflow-based approvals for material entries

---

## Reporting Architecture

All reports built from `journal_entries`:

### Financial Statements
- **Trial Balance**: `SELECT * FROM trial_balance`
- **Income Statement**: Filter `revenue` and `expense` accounts
- **Balance Sheet**: Filter `asset`, `liability`, `equity` accounts
- **Cash Flow**: Analyze cash account (1000) transactions

### Sub-Ledger Reports
- **Vendor Ledger**:
  ```sql
  SELECT * FROM journal_entry_lines
  WHERE dimension_1 = vendor_id
  ```
- **Customer Ledger**:
  ```sql
  SELECT * FROM journal_entry_lines
  WHERE dimension_2 = customer_id
  ```
- **AP Aging**: Calculate from vendor ledger + due dates
- **AR Aging**: Calculate from customer ledger + due dates

### Analytical Reports
- **Project Profitability**: Filter by `dimension_3`
- **Cost Center Analysis**: Filter by `dimension_4`
- **Multi-dimensional**: Combine dimensions

---

## Migration Strategy

### For Existing Systems:

1. **Phase 1: Dual Write** (Transition Period)
   - Keep AP/AR services enabled
   - JE module also available
   - Users choose which to use

2. **Phase 2: Read-Only AP/AR** (Training Period)
   - Disable POST endpoints
   - Keep GET endpoints for historical data
   - Train users on JE module

3. **Phase 3: Full Migration**
   - All new entries via JE module only
   - AP/AR services deprecated
   - Historical data accessible via reports

4. **Phase 4: Cleanup**
   - Drop ap_invoices, ar_invoices tables
   - Archive historical data if needed

---

## Benefits Summary

### Technical Benefits:
- ✅ Single source of truth
- ✅ No data synchronization issues
- ✅ Simplified architecture
- ✅ Faster queries (no complex JOINs)
- ✅ Reduced storage (no duplicate data)
- ✅ Perfect reconciliation (sub-ledgers = GL views)

### Accounting Benefits:
- ✅ GAAP/IFRS compliant
- ✅ Complete audit trail
- ✅ Immutable event log
- ✅ Double-entry validation
- ✅ Sub-ledger control account protection
- ✅ Multi-dimensional analysis

### Business Benefits:
- ✅ Real-time financial data
- ✅ Accurate reporting (no variance)
- ✅ Flexible dimensions (project, cost center, etc.)
- ✅ Scalable to any transaction type
- ✅ Easier to audit
- ✅ Lower maintenance cost

---

## Conclusion

**The Journal Entry is the foundation of accounting.**

By making JE the single entry point for all financial transactions, we achieve:
1. Data integrity
2. System simplicity
3. Perfect reconciliation
4. Compliance with accounting standards

**Recommendation**: Implement JE-First architecture and deprecate direct AP/AR posting.

**Version**: 2.5.0
**Date**: 2025-10-19
**Author**: AIRP Development Team
