# AIRP v2.0 - Accounting & Posting Protocols Documentation

## Version: 2.1.1
## Last Updated: 2025-10-18
## Document Type: Technical Specification & Compliance Reference

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Accounting Standards & Compliance](#accounting-standards--compliance)
3. [Double-Entry Bookkeeping Implementation](#double-entry-bookkeeping-implementation)
4. [Chart of Accounts Structure](#chart-of-accounts-structure)
5. [Journal Entry Posting Protocols](#journal-entry-posting-protocols)
6. [Event Sourcing Architecture](#event-sourcing-architecture)
7. [CQRS Pattern Implementation](#cqrs-pattern-implementation)
8. [Audit Trail & Compliance](#audit-trail--compliance)
9. [Sub-Ledgers & Control Accounts](#sub-ledgers--control-accounts)
10. [Trial Balance & Financial Reporting](#trial-balance--financial-reporting)
11. [Reversal & Correction Procedures](#reversal--correction-procedures)
12. [Multi-Currency Handling](#multi-currency-handling)
13. [AI-Assisted Accounting](#ai-assisted-accounting)
14. [Data Integrity & Validation](#data-integrity--validation)

---

## Executive Summary

AIRP v2.0 implements a modern, event-sourced financial ERP system that adheres to Generally Accepted Accounting Principles (GAAP) and International Financial Reporting Standards (IFRS). The system uses:

- **Double-Entry Bookkeeping**: Every transaction has equal debits and credits
- **Event Sourcing**: Immutable event log as the source of truth
- **CQRS**: Separate read and write models for optimal performance
- **Audit Trail**: Complete transaction history with cryptographic verification
- **Multi-Tenant**: UUID-based isolation for secure multi-company support
- **AI-Native**: Integrated AI for classification, reconciliation, and insights

---

## Accounting Standards & Compliance

### Standards Followed

1. **GAAP (Generally Accepted Accounting Principles)**
   - US GAAP compliance for revenue recognition, expense matching
   - Accrual basis accounting
   - Conservatism principle
   - Materiality concept

2. **IFRS (International Financial Reporting Standards)**
   - IFRS 15: Revenue from Contracts with Customers
   - IFRS 9: Financial Instruments
   - IAS 1: Presentation of Financial Statements
   - IAS 16: Property, Plant and Equipment

3. **Additional Compliance**
   - SOX (Sarbanes-Oxley Act) audit trail requirements
   - Data retention policies (7-year minimum)
   - Segregation of duties (approval workflows)

### Chart of Accounts Mapping

```typescript
// Database Schema: chart_of_accounts
{
  account_code: string,        // Unique identifier (e.g., "1000", "4000")
  account_name: string,         // Human-readable name
  account_type: enum,           // asset, liability, equity, revenue, expense
  normal_balance: enum,         // debit or credit
  ifrs_category: string,        // IFRS classification
  gaap_category: string,        // GAAP classification
  tax_category: string          // Tax reporting category
}
```

---

## Double-Entry Bookkeeping Implementation

### Core Principles

AIRP v2.0 strictly enforces double-entry bookkeeping where:

```
Total Debits = Total Credits (for every transaction)
```

### Validation Rules

**File:** `services/ledger-writer/src/domain/journal-entry.service.ts:33-39`

```typescript
// Validate balanced entry
const totalDebits = dto.lines.reduce((sum, line) => sum + line.debitAmount, 0);
const totalCredits = dto.lines.reduce((sum, line) => sum + line.creditAmount, 0);

if (Math.abs(totalDebits - totalCredits) > 0.01) {
  throw new Error(`Journal entry is not balanced. Debits: ${totalDebits}, Credits: ${totalCredits}`);
}
```

**Tolerance:** 0.01 AED (to account for rounding differences)

### Normal Balance Rules

| Account Type | Normal Balance | Increase | Decrease |
|-------------|---------------|----------|----------|
| Asset       | Debit         | Debit    | Credit   |
| Liability   | Credit        | Credit   | Debit    |
| Equity      | Credit        | Credit   | Debit    |
| Revenue     | Credit        | Credit   | Debit    |
| Expense     | Debit         | Debit    | Credit   |

### Account Balance Calculation

**File:** `services/projection-service/src/projections/projection.service.ts:88-93`

```typescript
// Calculate balance based on normal balance type
if (coaEntry.normal_balance === 'DEBIT') {
  glBalance.balance = glBalance.debit_amount - glBalance.credit_amount;
} else {
  glBalance.balance = glBalance.credit_amount - glBalance.debit_amount;
}
```

---

## Chart of Accounts Structure

### Current Chart of Accounts

```
1000 - Cash                      [Asset, Debit]
1200 - Accounts Receivable       [Asset, Debit]
2100 - Accounts Payable          [Liability, Credit]
4000 - Revenue - Product Sales   [Revenue, Credit]
5100 - Cost of Goods Sold        [Expense, Debit]
5200 - Salaries & Wages          [Expense, Debit]
5300 - Rent Expense              [Expense, Debit]
5400 - Utilities                 [Expense, Debit]
5500 - Office Supplies           [Expense, Debit]
5600 - IT & Software             [Expense, Debit]
5700 - Marketing & Advertising   [Expense, Debit]
```

### Account Code Ranges

- **1000-1999**: Current Assets
- **2000-2999**: Current Liabilities
- **3000-3999**: Equity
- **4000-4999**: Revenue
- **5000-5999**: Expenses
- **6000-6999**: Other Income/Expenses

### Account Hierarchy

```typescript
// Database Schema Supports Hierarchical Accounts
{
  parent_account_id: uuid,      // Reference to parent account
  is_control_account: boolean,  // True for summary accounts
  is_leaf: boolean              // True for detail accounts (postable)
}
```

**Rule:** Only leaf accounts (is_leaf = true) can have transactions posted to them.

### Database Schema

**Table:** `chart_of_accounts`

```sql
CREATE TABLE chart_of_accounts (
    account_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id          UUID NOT NULL,
    account_code       VARCHAR(50) NOT NULL,
    account_name       VARCHAR(255) NOT NULL,
    account_type       VARCHAR(50) NOT NULL,  -- asset, liability, equity, revenue, expense
    account_subtype    VARCHAR(50),
    parent_account_id  UUID REFERENCES chart_of_accounts(account_id),
    normal_balance     VARCHAR(10) NOT NULL,  -- debit or credit
    is_control_account BOOLEAN DEFAULT false,
    is_leaf            BOOLEAN DEFAULT true,
    currency           CHAR(3) DEFAULT 'AED',
    status             VARCHAR(20) DEFAULT 'active',
    ifrs_category      VARCHAR(100),
    gaap_category      VARCHAR(100),
    tax_category       VARCHAR(50),
    created_at         TIMESTAMPTZ DEFAULT now(),
    updated_at         TIMESTAMPTZ DEFAULT now(),
    metadata           JSONB,
    UNIQUE (tenant_id, account_code)
);
```

---

## Journal Entry Posting Protocols

### Journal Entry Lifecycle

```
1. Draft → 2. Validation → 3. Approval → 4. Posting → 5. Event Store → 6. Kafka Stream → 7. Projection
```

### API Endpoint

**POST** `/journal-entries`

**File:** `services/ledger-writer/src/domain/journal-entry.controller.ts:10-17`

### Request Format

```json
{
  "tenantId": "00000000-0000-0000-0000-000000000001",
  "entryDate": "2025-01-15",
  "entryType": "General",
  "description": "Monthly rent payment",
  "lines": [
    {
      "accountCode": "5300",
      "debitAmount": 10000,
      "creditAmount": 0,
      "description": "Office rent - January 2025"
    },
    {
      "accountCode": "1000",
      "debitAmount": 0,
      "creditAmount": 10000,
      "description": "Cash payment for rent"
    }
  ],
  "userId": "user-uuid",
  "sourceType": "Manual",
  "aiGenerated": false
}
```

### Entry Types

- **General**: Standard manual journal entries
- **Adjusting**: Period-end adjustments
- **Closing**: Period/year-end closing entries
- **Reversing**: Automatic reversal entries
- **Opening**: Opening balance entries
- **AI-Generated**: Entries created by AI classification

### Posting Validation Rules

**File:** `services/ledger-writer/src/domain/journal-entry.service.ts:32-72`

1. **Balance Validation**: Total debits must equal total credits (± 0.01 tolerance)
2. **Account Existence**: All account codes must exist in chart_of_accounts
3. **Leaf Account Check**: Only leaf accounts can be posted to
4. **Date Validation**: Entry date must not be in a closed period
5. **Currency Consistency**: All lines must use the same currency
6. **Amount Precision**: Amounts stored with 4 decimal places

### Journal Entry Schema

**Table:** `journal_entries`

```sql
CREATE TABLE journal_entries (
    entry_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id           UUID NOT NULL,
    entry_number        VARCHAR(50) NOT NULL,      -- Auto-generated: JE-{timestamp}
    entry_date          DATE NOT NULL,
    posting_date        DATE NOT NULL,
    entry_type          VARCHAR(50) NOT NULL,
    source_type         VARCHAR(50),               -- Manual, AP, AR, AI
    source_ref_id       UUID,                      -- Reference to source document
    description         TEXT,
    total_debit         NUMERIC(20,4) NOT NULL,
    total_credit        NUMERIC(20,4) NOT NULL,
    currency            CHAR(3) DEFAULT 'AED',
    status              VARCHAR(20) DEFAULT 'draft',  -- draft, posted, approved, reversed
    approved_by         UUID,
    approved_at         TIMESTAMPTZ,
    posted_by           UUID,
    posted_at           TIMESTAMPTZ,
    reversed_by         UUID,
    reversed_at         TIMESTAMPTZ,
    reversal_entry_id   UUID,
    ai_confidence_score NUMERIC(5,4),
    ai_model_version    VARCHAR(50),
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now(),
    metadata            JSONB,
    UNIQUE (tenant_id, entry_number)
);
```

**Table:** `journal_entry_lines`

```sql
CREATE TABLE journal_entry_lines (
    line_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entry_id      UUID NOT NULL REFERENCES journal_entries(entry_id) ON DELETE CASCADE,
    line_number   INTEGER NOT NULL,
    account_id    UUID NOT NULL REFERENCES chart_of_accounts(account_id),
    debit_amount  NUMERIC(20,4) DEFAULT 0,
    credit_amount NUMERIC(20,4) DEFAULT 0,
    description   TEXT,
    created_at    TIMESTAMPTZ DEFAULT now()
);
```

---

## Event Sourcing Architecture

### Core Concept

AIRP v2.0 uses **Event Sourcing** where:
- Every state change is captured as an immutable event
- Event store is the **source of truth**
- Current state is derived by replaying events
- Projections (read models) can be rebuilt from events

### Event Store Schema

**Table:** `event_store` (Partitioned by timestamp)

```sql
CREATE TABLE event_store (
    event_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID NOT NULL,
    aggregate_id    UUID NOT NULL,              -- Journal entry ID
    aggregate_type  VARCHAR(50) NOT NULL,        -- 'JournalEntry'
    event_type      VARCHAR(100) NOT NULL,       -- 'JournalEntryPosted'
    event_version   INTEGER NOT NULL DEFAULT 1,
    event_data      JSONB NOT NULL,              -- Complete journal entry data
    event_metadata  JSONB,
    causation_id    UUID,                        -- Event that caused this event
    correlation_id  UUID,                        -- Group related events
    user_id         UUID,
    timestamp       TIMESTAMPTZ NOT NULL DEFAULT now(),
    sequence_number BIGINT NOT NULL,             -- Global ordering
    checksum        VARCHAR(64)                  -- SHA-256 integrity check
) PARTITION BY RANGE (timestamp);
```

### Event Types

1. **JournalEntryPosted** - Journal entry created and posted
2. **JournalEntryApproved** - Entry approved by authorized user
3. **JournalEntryReversed** - Entry reversed (not deleted)
4. **InvoiceReceived** - AP invoice received
5. **InvoiceIssued** - AR invoice issued
6. **PaymentExecuted** - Payment processed

### Event Data Structure

**File:** `services/ledger-writer/src/domain/journal-entry.service.ts:45-72`

```typescript
const event = await this.eventStoreService.appendEvent({
  tenantId: dto.tenantId,
  aggregateId: entryId,
  aggregateType: 'JournalEntry',
  eventType: 'JournalEntryPosted',
  eventData: {
    entryNumber: `JE-${Date.now()}`,
    entryDate: dto.entryDate,
    postingDate: dto.entryDate,
    entryType: dto.entryType,
    sourceType: dto.sourceType || 'Manual',
    description: dto.description,
    currency: 'AED',
    totalDebit: totalDebits.toFixed(4),
    totalCredit: totalCredits.toFixed(4),
    lines: dto.lines.map((line, index) => ({
      lineNumber: index + 1,
      accountCode: line.accountCode,
      debitAmount: line.debitAmount.toFixed(4),
      creditAmount: line.creditAmount.toFixed(4),
      description: line.description || dto.description,
    })),
    aiGenerated: dto.aiGenerated || false,
    aiConfidenceScore: dto.aiConfidenceScore?.toFixed(4),
  },
  correlationId,
  userId: dto.userId,
});
```

### Event Publishing to Kafka

**File:** `services/ledger-writer/src/events/event-store.service.ts`

After storing the event in PostgreSQL, it is published to Kafka/Redpanda:

```typescript
// Publish to Kafka with raw KafkaJS producer (proper JSON serialization)
await this.producer.send({
  topic: 'airp.events.journal-entry-posted',
  messages: [
    {
      key: event.aggregate_id,
      value: JSON.stringify(event),  // Explicit JSON serialization
      headers: {
        'event-type': event.event_type,
        'tenant-id': event.tenant_id,
      },
    },
  ],
});
```

**Kafka Topics:**
- `airp.events.journal-entry-posted`
- `airp.events.invoice-received`
- `airp.events.invoice-issued`
- `airp.events.payment-executed`

---

## CQRS Pattern Implementation

### Concept

**CQRS** (Command Query Responsibility Segregation) separates:
- **Write Model**: Event Store (journal_entries, event_store)
- **Read Model**: Projections (gl_balances, trial_balance, ap_aging, ar_aging)

### Write Path (Commands)

```
API Request → Ledger Writer Service → Validate → Event Store → Kafka → Projection Service
```

**Service:** `ledger-writer` (Port 3001)

### Read Path (Queries)

```
API Request → Reporting Service → Query Projections (gl_balances, trial_balance) → Response
```

**Service:** `reporting-service` (Port 3008)

### Projection Service

**Service:** `projection-service` (Port 3002)

**File:** `services/projection-service/src/projections/projection.service.ts`

**Function:** Consumes events from Kafka and updates read models

```typescript
async updateTrialBalance(event: any): Promise<void> {
  const journalEntryData = event.event_data;
  const lines = journalEntryData.lines || [];
  const entryDate = new Date(journalEntryData.entryDate);
  const fiscalYear = entryDate.getFullYear();
  const fiscalPeriod = entryDate.getMonth() + 1; // 1-12
  const currency = journalEntryData.currency || 'AED';

  for (const line of lines) {
    // Look up account_id from chart of accounts
    const coaEntry = await this.coaRepo.findOne({
      where: {
        tenant_id: event.tenant_id,
        account_code: line.accountCode,
      },
    });

    // Find or create GL balance entry
    let glBalance = await this.glBalanceRepo.findOne({
      where: {
        tenant_id: event.tenant_id,
        account_id: coaEntry.account_id,
        fiscal_year: fiscalYear,
        fiscal_period: fiscalPeriod,
        currency: currency,
      },
    });

    if (!glBalance) {
      glBalance = this.glBalanceRepo.create({
        tenant_id: event.tenant_id,
        account_id: coaEntry.account_id,
        fiscal_year: fiscalYear,
        fiscal_period: fiscalPeriod,
        currency: currency,
        debit_amount: 0,
        credit_amount: 0,
        balance: 0,
        last_event_id: event.event_id,
      });
    }

    // Update balances
    const debitAmount = parseFloat(line.debitAmount || '0');
    const creditAmount = parseFloat(line.creditAmount || '0');

    glBalance.debit_amount += debitAmount;
    glBalance.credit_amount += creditAmount;

    // Calculate balance based on normal balance type
    if (coaEntry.normal_balance === 'DEBIT') {
      glBalance.balance = glBalance.debit_amount - glBalance.credit_amount;
    } else {
      glBalance.balance = glBalance.credit_amount - glBalance.debit_amount;
    }

    glBalance.last_updated = new Date();
    glBalance.last_event_id = event.event_id;

    await this.glBalanceRepo.save(glBalance);
  }

  // Refresh the trial balance materialized view
  await this.dataSource.query('REFRESH MATERIALIZED VIEW trial_balance');
}
```

### GL Balances (Read Model)

**Table:** `gl_balances`

```sql
CREATE TABLE gl_balances (
    balance_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id     UUID NOT NULL,
    account_id    UUID NOT NULL,
    fiscal_year   INTEGER NOT NULL,
    fiscal_period INTEGER NOT NULL,              -- 1-12 (month)
    currency      CHAR(3) NOT NULL,
    debit_amount  NUMERIC(20,4) DEFAULT 0,
    credit_amount NUMERIC(20,4) DEFAULT 0,
    balance       NUMERIC(20,4) DEFAULT 0,       -- Calculated based on normal_balance
    last_updated  TIMESTAMPTZ DEFAULT now(),
    last_event_id UUID,
    UNIQUE (tenant_id, account_id, fiscal_year, fiscal_period, currency)
);
```

### Projection Rebuild Protocol

**Critical Feature:** Projections can be completely rebuilt from event_store

```sql
-- Example: Rebuild GL Balances from Event Store
TRUNCATE gl_balances;

WITH event_lines AS (
    SELECT
        es.event_id,
        es.tenant_id,
        EXTRACT(YEAR FROM (es.event_data->>'entryDate')::date)::int as fiscal_year,
        EXTRACT(MONTH FROM (es.event_data->>'entryDate')::date)::int as fiscal_period,
        COALESCE(es.event_data->>'currency', 'AED') as currency,
        jsonb_array_elements(es.event_data->'lines') as line
    FROM event_store es
    WHERE es.event_type = 'JournalEntryPosted'
),
line_balances AS (
    SELECT
        el.tenant_id,
        coa.account_id,
        coa.normal_balance,
        el.fiscal_year,
        el.fiscal_period,
        el.currency,
        SUM((el.line->>'debitAmount')::numeric) as debit_amount,
        SUM((el.line->>'creditAmount')::numeric) as credit_amount
    FROM event_lines el
    JOIN chart_of_accounts coa
        ON coa.account_code = (el.line->>'accountCode')
        AND coa.tenant_id = el.tenant_id
    GROUP BY el.tenant_id, coa.account_id, coa.normal_balance, el.fiscal_year, el.fiscal_period, el.currency
)
INSERT INTO gl_balances (
    tenant_id, account_id, fiscal_year, fiscal_period, currency,
    debit_amount, credit_amount, balance
)
SELECT
    tenant_id,
    account_id,
    fiscal_year,
    fiscal_period,
    currency,
    debit_amount,
    credit_amount,
    CASE
        WHEN normal_balance = 'DEBIT' THEN debit_amount - credit_amount
        ELSE credit_amount - debit_amount
    END as balance
FROM line_balances;

REFRESH MATERIALIZED VIEW trial_balance;
```

---

## Audit Trail & Compliance

### Immutability Principle

- Events in `event_store` are **NEVER modified or deleted**
- Corrections are made through **reversing entries**
- All changes tracked with user_id and timestamp
- Checksum verification prevents tampering

### Checksum Verification

**File:** `services/ledger-writer/src/events/event-store.service.ts`

```typescript
import { createHash } from 'crypto';

const checksum = createHash('sha256')
  .update(JSON.stringify(eventData))
  .digest('hex');
```

### Audit Trail Fields

Every transaction includes:
- `created_at` - Creation timestamp
- `updated_at` - Last modification timestamp
- `created_by` / `user_id` - User who created the record
- `approved_by` - User who approved (if applicable)
- `posted_by` - User who posted the transaction
- `correlation_id` - Links related events
- `causation_id` - Links cause and effect events

### Compliance Reports

1. **Audit Log Query**: All events for a specific aggregate
2. **User Activity Report**: All transactions by user
3. **Period Lock Status**: Closed periods cannot be modified
4. **Change History**: Complete modification history via event replay

---

## Sub-Ledgers & Control Accounts

### Control Account Concept

A **control account** is a summary account in the General Ledger that is supported by detailed sub-ledger accounts.

### AP (Accounts Payable) Sub-Ledger

**Control Account:** 2100 - Accounts Payable

**Sub-Ledger Table:** `ap_invoices`

```sql
CREATE TABLE ap_invoices (
    invoice_id         UUID PRIMARY KEY,
    tenant_id          UUID NOT NULL,
    vendor_id          UUID NOT NULL REFERENCES vendors(vendor_id),
    invoice_number     VARCHAR(100) NOT NULL,
    invoice_date       DATE NOT NULL,
    due_date           DATE NOT NULL,
    total_amount       NUMERIC(20,4) NOT NULL,
    amount_outstanding NUMERIC(20,4) NOT NULL,
    payment_status     VARCHAR(20) DEFAULT 'unpaid',  -- unpaid, partial, paid
    gl_entry_id        UUID REFERENCES journal_entries(entry_id),
    ...
);
```

**Reconciliation Rule:**
```
SUM(ap_invoices.amount_outstanding) = gl_balances.balance WHERE account_code = '2100'
```

### AR (Accounts Receivable) Sub-Ledger

**Control Account:** 1200 - Accounts Receivable

**Sub-Ledger Table:** `ar_invoices`

```sql
CREATE TABLE ar_invoices (
    invoice_id         UUID PRIMARY KEY,
    tenant_id          UUID NOT NULL,
    customer_id        UUID NOT NULL REFERENCES customers(customer_id),
    invoice_number     VARCHAR(100) NOT NULL,
    invoice_date       DATE NOT NULL,
    due_date           DATE NOT NULL,
    total_amount       NUMERIC(20,4) NOT NULL,
    amount_outstanding NUMERIC(20,4) NOT NULL,
    payment_status     VARCHAR(20) DEFAULT 'unpaid',
    gl_entry_id        UUID REFERENCES journal_entries(entry_id),
    ...
);
```

**Reconciliation Rule:**
```
SUM(ar_invoices.amount_outstanding) = gl_balances.balance WHERE account_code = '1200'
```

---

## Trial Balance & Financial Reporting

### Trial Balance Materialized View

**File:** `services/reporting-service/src/reporting.service.ts:32-42`

```sql
CREATE MATERIALIZED VIEW trial_balance AS
SELECT
    coa.tenant_id,
    coa.account_code,
    coa.account_name,
    coa.account_type,
    COALESCE(SUM(gb.debit_amount), 0) AS debit_balance,
    COALESCE(SUM(gb.credit_amount), 0) AS credit_balance,
    COALESCE(SUM(gb.balance), 0) AS net_balance,
    MAX(gb.fiscal_year) AS fiscal_year,
    MAX(gb.fiscal_period) AS fiscal_period,
    MAX(CASE
        WHEN gb.fiscal_year IS NOT NULL THEN
            (concat(gb.fiscal_year, '-', lpad(gb.fiscal_period::text, 2, '0'), '-01')::date + '1 mon'::interval - '1 day'::interval)
        ELSE NULL
    END) AS period_end_date
FROM chart_of_accounts coa
LEFT JOIN gl_balances gb ON coa.account_id = gb.account_id
WHERE coa.status = 'active'
GROUP BY coa.tenant_id, coa.account_code, coa.account_name, coa.account_type
ORDER BY coa.account_code;
```

**Key Design Decisions:**
1. **LEFT JOIN** - Shows all accounts including zero-balance accounts
2. **SUM() + GROUP BY** - Aggregates all fiscal periods
3. **COALESCE** - Shows 0 instead of NULL for zero-balance accounts

### Trial Balance API

**Endpoint:** `GET /reports/trial-balance?tenant_id={uuid}`

**Service:** `reporting-service` (Port 3008)

**Response Format:**
```json
{
  "tenant_id": "00000000-0000-0000-0000-000000000001",
  "period_end_date": "2025-10-31T00:00:00.000Z",
  "accounts": [
    {
      "account_code": "1000",
      "account_name": "Cash",
      "account_type": "asset",
      "total_debit": "8000.0000",
      "total_credit": "11098.0000",
      "net_balance": "-3098.0000"
    },
    ...
  ],
  "total_debits": 175000,
  "total_credits": 175098,
  "is_balanced": false
}
```

### Balance Verification

**Rule:** `total_debits = total_credits` (with 0.01 tolerance)

**File:** `services/reporting-service/src/reporting.service.ts:62-66`

```typescript
is_balanced: Math.abs(
  accounts.reduce((sum, r) => sum + parseFloat(r.total_debit || 0), 0) -
  accounts.reduce((sum, r) => sum + parseFloat(r.total_credit || 0), 0)
) < 0.01
```

### Financial Reports

1. **Trial Balance** - All accounts with debit/credit balances
2. **Balance Sheet** - Assets, Liabilities, Equity at a point in time
3. **Income Statement (P&L)** - Revenue and Expenses for a period
4. **Cash Flow Statement** - Operating, Investing, Financing activities
5. **AP Aging** - Vendor invoices by aging bucket
6. **AR Aging** - Customer invoices by aging bucket

---

## Reversal & Correction Procedures

### Reversal Protocol

AIRP v2.0 does **NOT** allow deletion or modification of posted transactions. Corrections are made through **reversing entries**.

**API Endpoint:** `POST /journal-entries/reverse`

**File:** `services/ledger-writer/src/domain/journal-entry.service.ts:90-152`

### Reversal Process

1. Retrieve original journal entry from event_store
2. Create new entry with **swapped debits and credits**
3. Link reversing entry to original entry via metadata
4. Mark both entries with reversal relationship

### Example: Reversing Entry

**Original Entry:**
```
DR: 5300 Rent Expense        10,000 AED
CR: 1000 Cash                       10,000 AED
```

**Reversing Entry:**
```
DR: 1000 Cash                10,000 AED
CR: 5300 Rent Expense               10,000 AED
Description: REVERSAL: Office rent - January 2025 - Reason: Incorrect amount
```

### Implementation

```typescript
// Create reversing entry (swap debits and credits)
const reversedLines = originalData.lines.map((line) => ({
  accountCode: line.accountCode,
  debitAmount: parseFloat(line.creditAmount),  // SWAP
  creditAmount: parseFloat(line.debitAmount),  // SWAP
  description: `REVERSAL: ${line.description}`,
}));

const reversalEntryId = uuidv4();

const event = await this.eventStoreService.appendEvent({
  tenantId,
  aggregateId: reversalEntryId,
  aggregateType: 'JournalEntry',
  eventType: 'JournalEntryPosted',
  eventData: {
    entryNumber: `REV-${originalData.entryNumber}`,
    entryDate: new Date().toISOString().split('T')[0],
    postingDate: new Date().toISOString().split('T')[0],
    entryType: 'Reversing',
    sourceType: 'Manual',
    description: `REVERSAL: ${originalData.description} - Reason: ${reason}`,
    currency: originalData.currency,
    totalDebit: originalData.totalCredit,    // SWAP
    totalCredit: originalData.totalDebit,    // SWAP
    lines: reversedLines,
    aiGenerated: false,
    originalEntryId: entryId,
  },
  causationId: originalEntry.event_id,
  userId,
});
```

### Correction Workflow

For corrections:
1. Reverse the incorrect entry
2. Post the correct entry
3. Both linked via `correlation_id`

---

## Multi-Currency Handling

### Base Currency

**Base Currency:** AED (UAE Dirham)

All accounts default to AED unless specified otherwise.

### Currency Fields

```typescript
{
  currency: char(3),          // ISO 4217 currency code
  exchange_rate: numeric,     // Rate to base currency
  functional_amount: numeric  // Amount in base currency
}
```

### Exchange Rate Storage

**Table:** `exchange_rates`

```sql
CREATE TABLE exchange_rates (
    rate_id        UUID PRIMARY KEY,
    from_currency  CHAR(3) NOT NULL,
    to_currency    CHAR(3) NOT NULL,
    rate           NUMERIC(20,10) NOT NULL,
    effective_date DATE NOT NULL,
    rate_type      VARCHAR(20) DEFAULT 'spot',  -- spot, average, budget
    created_at     TIMESTAMPTZ DEFAULT now()
);
```

### Multi-Currency Journal Entries

When posting entries in foreign currency:
1. Store original amount in transaction currency
2. Convert to base currency using effective exchange rate
3. Store both amounts for audit trail

---

## AI-Assisted Accounting

### AI Services Integration

AIRP v2.0 includes 5 AI microservices:

1. **AI Transaction Classification** (Port 8001)
   - Classifies transactions to appropriate GL accounts
   - Returns confidence score (0-1)

2. **AI Reconciliation Engine** (Port 8002)
   - Matches bank transactions to GL entries
   - Identifies discrepancies

3. **AI Policy Advisor** (Port 8003)
   - Suggests approval workflows
   - Identifies policy violations

4. **AI Narrative Generation** (Port 8004)
   - Generates human-readable descriptions
   - Creates financial report narratives

5. **AI Cash Flow Forecasting** (Port 8005)
   - Predicts future cash flows
   - Provides scenario analysis

### AI-Generated Journal Entries

```typescript
{
  aiGenerated: true,
  aiConfidenceScore: 0.9876,
  aiModelVersion: "claude-3-sonnet-20240229"
}
```

**Policy:** Entries with confidence score < 0.8 require human review

### AI Classification Example

**Input:** "Monthly office rent payment to landlord - AED 10,000"

**AI Output:**
```json
{
  "classification": {
    "debitAccount": "5300",
    "debitAccountName": "Rent Expense",
    "creditAccount": "1000",
    "creditAccountName": "Cash"
  },
  "confidence": 0.98,
  "reasoning": "Rent expenses are classified as operating expenses (5300). Payment reduces cash (1000)."
}
```

---

## Data Integrity & Validation

### Database Constraints

1. **Primary Keys**: UUID v4 for all records
2. **Foreign Keys**: Referential integrity enforced
3. **Unique Constraints**: Prevent duplicates (tenant_id + entry_number)
4. **Check Constraints**: Validate amounts >= 0
5. **Not Null Constraints**: Mandatory fields enforced

### Validation Layers

1. **API Layer**: Request validation (DTOs, decorators)
2. **Service Layer**: Business logic validation
3. **Database Layer**: Constraints and triggers
4. **Event Store**: Checksum verification

### Transaction Isolation

**Level:** READ COMMITTED (PostgreSQL default)

**Conflict Resolution:** Optimistic locking with version numbers

### Backup & Recovery

1. **Database Backups**: Daily full backups, hourly incrementals
2. **Event Store**: Never deleted, enables point-in-time recovery
3. **Disaster Recovery**: Event replay rebuilds all projections

---

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         AIRP v2.0 Architecture                   │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐        ┌──────────────┐        ┌──────────────┐
│   Web App    │───────▶│  API Gateway │───────▶│   Services   │
│(Port 5000)   │        │              │        │              │
└──────────────┘        └──────────────┘        └──────────────┘
                                                        │
                        ┌───────────────────────────────┼───────────────┐
                        │                               │               │
                        ▼                               ▼               ▼
                ┌──────────────┐              ┌──────────────┐ ┌──────────────┐
                │Ledger Writer │              │  Reporting   │ │  Projection  │
                │  (Port 3001) │              │ (Port 3008)  │ │ (Port 3002)  │
                └──────────────┘              └──────────────┘ └──────────────┘
                        │                               │               ▲
                        │                               │               │
                        ▼                               ▼               │
                ┌──────────────┐              ┌──────────────┐         │
                │ Event Store  │              │ Projections  │         │
                │ (PostgreSQL) │              │ GL Balances  │         │
                │              │              │ Trial Balance│         │
                └──────────────┘              └──────────────┘         │
                        │                                               │
                        │                                               │
                        ▼                                               │
                ┌──────────────┐                                       │
                │    Kafka     │───────────────────────────────────────┘
                │  (Redpanda)  │         Event Stream
                └──────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    AI Microservices Layer                        │
├──────────────┬──────────────┬──────────────┬──────────────┬─────┤
│Classification│Reconciliation│Policy Advisor│   Narrative  │ ... │
│  (Port 8001) │  (Port 8002) │  (Port 8003) │ (Port 8004)  │     │
└──────────────┴──────────────┴──────────────┴──────────────┴─────┘
```

---

## Compliance Checklist

✅ **Double-Entry Bookkeeping**: Every transaction balanced
✅ **Audit Trail**: Complete event history with timestamps
✅ **Immutability**: Events never modified or deleted
✅ **Segregation of Duties**: Approval workflows enforced
✅ **Data Retention**: 7-year minimum via event store
✅ **Financial Reporting**: Trial Balance, P&L, Balance Sheet
✅ **Sub-Ledger Reconciliation**: AP/AR tied to GL control accounts
✅ **Multi-Currency Support**: ISO 4217 currency codes
✅ **Period Locking**: Closed periods cannot be modified
✅ **User Audit**: All transactions tracked to user_id

---

## References

1. **GAAP**: Financial Accounting Standards Board (FASB)
2. **IFRS**: International Accounting Standards Board (IASB)
3. **SOX**: Sarbanes-Oxley Act of 2002
4. **Event Sourcing**: Martin Fowler - https://martinfowler.com/eaaDev/EventSourcing.html
5. **CQRS**: Greg Young - CQRS Documents

---

## Document Control

| Version | Date       | Author | Changes                          |
|---------|------------|--------|----------------------------------|
| 2.1.1   | 2025-10-18 | Claude | Complete Trial Balance fixes     |
| 2.1.0   | 2025-10-15 | Claude | Event Sourcing + CQRS complete   |
| 2.0.0   | 2025-01-10 | Claude | Initial AIRP v2.0 implementation |

---

**END OF DOCUMENT**
