# AIRP v2.0 - SQL Queries Reference

This document contains all SQL queries used in the Reporting Service API endpoints.

---

## 1. Vendor Ledger Query

**Purpose:** Retrieve all AP invoices for a specific vendor with running balance

**File:** `C:\Dev\AIRP2\services\reporting-service\src\reporting.service.ts`
**Method:** `getVendorLedger()`

```sql
SELECT
  ai.invoice_id,
  ai.invoice_number,
  ai.invoice_date,
  ai.due_date,
  ai.subtotal,
  ai.tax_amount,
  ai.total_amount,
  ai.amount_paid,
  ai.amount_outstanding,
  ai.status,
  ai.payment_status,
  v.vendor_name,
  v.vendor_code,
  ai.created_at
FROM ap_invoices ai
JOIN vendors v ON ai.vendor_id = v.vendor_id
WHERE ai.tenant_id = $1
  AND ai.vendor_id = $2
ORDER BY ai.invoice_date ASC, ai.created_at ASC;
```

**Parameters:**
- `$1` - tenant_id (UUID)
- `$2` - vendor_id (UUID)

**Post-Processing:**
- Calculates running balance in application code
- Running balance = cumulative sum of amount_outstanding

---

## 2. Customer Ledger Query

**Purpose:** Retrieve all AR invoices for a specific customer with running balance

**File:** `C:\Dev\AIRP2\services\reporting-service\src\reporting.service.ts`
**Method:** `getCustomerLedger()`

```sql
SELECT
  ai.invoice_id,
  ai.invoice_number,
  ai.invoice_date,
  ai.due_date,
  ai.subtotal,
  ai.tax_amount,
  ai.total_amount,
  ai.amount_paid,
  ai.amount_outstanding,
  ai.status,
  ai.payment_status,
  c.customer_name,
  c.customer_code,
  ai.created_at
FROM ar_invoices ai
JOIN customers c ON ai.customer_id = c.customer_id
WHERE ai.tenant_id = $1
  AND ai.customer_id = $2
ORDER BY ai.invoice_date ASC, ai.created_at ASC;
```

**Parameters:**
- `$1` - tenant_id (UUID)
- `$2` - customer_id (UUID)

**Post-Processing:**
- Calculates running balance in application code
- Running balance = cumulative sum of amount_outstanding

---

## 3. Account Balances Query

**Purpose:** Retrieve balances from gl_balances table grouped by account

**File:** `C:\Dev\AIRP2\services\reporting-service\src\reporting.service.ts`
**Method:** `getAccountBalances()`

```sql
SELECT
  gb.account_id,
  coa.account_code,
  coa.account_name,
  coa.account_type,
  coa.account_subtype,
  gb.fiscal_year,
  gb.fiscal_period,
  gb.currency,
  SUM(gb.debit_amount) as total_debit,
  SUM(gb.credit_amount) as total_credit,
  SUM(gb.balance) as net_balance
FROM gl_balances gb
JOIN chart_of_accounts coa ON gb.account_id = coa.account_id
WHERE gb.tenant_id = $1
GROUP BY
  gb.account_id,
  coa.account_code,
  coa.account_name,
  coa.account_type,
  coa.account_subtype,
  gb.fiscal_year,
  gb.fiscal_period,
  gb.currency
ORDER BY coa.account_code, gb.fiscal_year, gb.fiscal_period;
```

**Parameters:**
- `$1` - tenant_id (UUID)

**Post-Processing:**
- Groups results by account_code in application code
- Creates period-by-period breakdown array
- Calculates totals per account

---

## 4. Income Statement Query

**Purpose:** Query gl_balances for revenue and expense accounts

**File:** `C:\Dev\AIRP2\services\reporting-service\src\reporting.service.ts`
**Method:** `getIncomeStatement()`

```sql
SELECT
  coa.account_id,
  coa.account_code,
  coa.account_name,
  coa.account_type,
  coa.account_subtype,
  gb.fiscal_year,
  gb.fiscal_period,
  SUM(gb.debit_amount) as total_debit,
  SUM(gb.credit_amount) as total_credit,
  SUM(gb.balance) as net_balance
FROM gl_balances gb
JOIN chart_of_accounts coa ON gb.account_id = coa.account_id
WHERE gb.tenant_id = $1
  AND coa.account_type IN ('Revenue', 'Expense')
  -- Optional: Date range filters
  AND gb.fiscal_year >= EXTRACT(YEAR FROM $2::date)  -- if start_date provided
  AND gb.fiscal_year <= EXTRACT(YEAR FROM $3::date)  -- if end_date provided
GROUP BY
  coa.account_id,
  coa.account_code,
  coa.account_name,
  coa.account_type,
  coa.account_subtype,
  gb.fiscal_year,
  gb.fiscal_period
ORDER BY coa.account_type DESC, coa.account_code;
```

**Parameters:**
- `$1` - tenant_id (UUID)
- `$2` - start_date (optional, DATE)
- `$3` - end_date (optional, DATE)

**Post-Processing:**
- Separates revenue and expense accounts
- Calculates amount for each account:
  - Revenue: credit_amount - debit_amount
  - Expense: debit_amount - credit_amount
- Calculates totals:
  - Total Revenue
  - Total Expenses
  - Net Income = Total Revenue - Total Expenses
  - Profit Margin = (Net Income / Total Revenue) * 100

---

## 5. Balance Sheet Query

**Purpose:** Query gl_balances for asset, liability, and equity accounts

**File:** `C:\Dev\AIRP2\services\reporting-service\src\reporting.service.ts`
**Method:** `getBalanceSheet()`

```sql
SELECT
  coa.account_id,
  coa.account_code,
  coa.account_name,
  coa.account_type,
  coa.account_subtype,
  gb.fiscal_year,
  gb.fiscal_period,
  SUM(gb.debit_amount) as total_debit,
  SUM(gb.credit_amount) as total_credit,
  SUM(gb.balance) as net_balance
FROM gl_balances gb
JOIN chart_of_accounts coa ON gb.account_id = coa.account_id
WHERE gb.tenant_id = $1
  AND coa.account_type IN ('Asset', 'Liability', 'Equity')
  -- Optional: As-of-date filter
  AND MAKE_DATE(gb.fiscal_year, gb.fiscal_period, 1) <= $2::date  -- if as_of_date provided
GROUP BY
  coa.account_id,
  coa.account_code,
  coa.account_name,
  coa.account_type,
  coa.account_subtype,
  gb.fiscal_year,
  gb.fiscal_period
ORDER BY coa.account_type, coa.account_code;
```

**Parameters:**
- `$1` - tenant_id (UUID)
- `$2` - as_of_date (optional, DATE)

**Post-Processing:**
- Separates into three categories: Assets, Liabilities, Equity
- Calculates balance for each account:
  - Assets: debit_amount - credit_amount
  - Liabilities: credit_amount - debit_amount
  - Equity: credit_amount - debit_amount
- Validates accounting equation:
  - is_balanced = |Total Assets - (Total Liabilities + Total Equity)| < 0.01
  - variance = Total Assets - (Total Liabilities + Total Equity)

---

## 6. Cash Flow Statement Query

**Purpose:** Query bank_transactions for cash movements

**File:** `C:\Dev\AIRP2\services\reporting-service\src\reporting.service.ts`
**Method:** `getCashFlow()`

```sql
SELECT
  bt.transaction_id,
  bt.transaction_date,
  bt.value_date,
  bt.description,
  bt.reference,
  bt.debit_amount,
  bt.credit_amount,
  bt.balance,
  bt.currency,
  ba.account_name as bank_account_name,
  ba.account_code as bank_account_code
FROM bank_transactions bt
JOIN bank_accounts ba ON bt.bank_account_id = ba.bank_account_id
WHERE bt.tenant_id = $1
  -- Optional: Date range filters
  AND bt.transaction_date >= $2::date  -- if start_date provided
  AND bt.transaction_date <= $3::date  -- if end_date provided
ORDER BY bt.transaction_date ASC, bt.value_date ASC;
```

**Parameters:**
- `$1` - tenant_id (UUID)
- `$2` - start_date (optional, DATE)
- `$3` - end_date (optional, DATE)

**Post-Processing:**
- Categorizes transactions based on description keywords:
  - **Operating**: Default category (customer/vendor payments, operating expenses)
  - **Investing**: Contains "invest", "asset purchase", "equipment"
  - **Financing**: Contains "loan", "dividend", "capital"
- Calculates for each transaction:
  - net_amount = credit_amount - debit_amount
- Calculates summary:
  - total_inflows = sum of all credit_amount
  - total_outflows = sum of all debit_amount
  - net_cash_flow = total_inflows - total_outflows
  - opening_balance = first transaction's balance - first transaction's net_amount
  - closing_balance = last transaction's balance
  - operating_cash_flow = sum of net_amount for operating activities
  - investing_cash_flow = sum of net_amount for investing activities
  - financing_cash_flow = sum of net_amount for financing activities

---

## Query Performance Notes

### Indexed Columns Used

All queries leverage existing database indexes for optimal performance:

1. **ap_invoices**
   - `idx_ap_invoices_tenant` (tenant_id)
   - `idx_ap_invoices_vendor` (vendor_id)
   - `idx_ap_invoices_date` (invoice_date)

2. **ar_invoices**
   - `idx_ar_invoices_tenant` (tenant_id)
   - `idx_ar_invoices_customer` (customer_id)
   - `idx_ar_invoices_date` (invoice_date)

3. **gl_balances**
   - `idx_gl_balances_tenant` (tenant_id)
   - `idx_gl_balances_account` (account_id)
   - `idx_gl_balances_period` (fiscal_year, fiscal_period)

4. **chart_of_accounts**
   - `idx_coa_tenant` (tenant_id)
   - `idx_coa_type` (account_type)
   - `idx_coa_code` (account_code)

5. **bank_transactions**
   - `idx_bank_trans_account` (bank_account_id)
   - `idx_bank_trans_date` (transaction_date)

### Query Optimization Tips

1. **Always include tenant_id filter** - Ensures partition pruning and index usage
2. **Use date range filters** - Limits result set size for large databases
3. **Consider pagination** - For large result sets (not currently implemented)
4. **Use materialized views** - For frequently accessed aggregations
5. **Monitor query plans** - Use EXPLAIN ANALYZE for slow queries

---

## Database Views Available

The schema includes pre-built views that can be used for reporting:

### 1. trial_balance (Materialized View)

```sql
SELECT
  tenant_id,
  fiscal_year,
  fiscal_period,
  account_id,
  SUM(debit_amount) as total_debits,
  SUM(credit_amount) as total_credits,
  SUM(balance) as ending_balance,
  MAX(last_updated) as as_of_date
FROM gl_balances
GROUP BY tenant_id, fiscal_year, fiscal_period, account_id;
```

### 2. income_statement (View)

```sql
SELECT
  je.tenant_id,
  EXTRACT(YEAR FROM je.entry_date) as fiscal_year,
  EXTRACT(MONTH FROM je.entry_date) as fiscal_period,
  coa.account_type,
  coa.account_code,
  coa.account_name,
  SUM(jel.debit_amount) as total_debit,
  SUM(jel.credit_amount) as total_credit,
  CASE
    WHEN coa.account_type = 'Revenue' THEN SUM(jel.credit_amount - jel.debit_amount)
    WHEN coa.account_type = 'Expense' THEN SUM(jel.debit_amount - jel.credit_amount)
    ELSE 0
  END as net_amount
FROM journal_entries je
JOIN journal_entry_lines jel ON je.entry_id = jel.entry_id
JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
WHERE je.status = 'posted'
  AND coa.account_type IN ('Revenue', 'Expense')
GROUP BY je.tenant_id, fiscal_year, fiscal_period, coa.account_type, coa.account_code, coa.account_name;
```

### 3. balance_sheet (View)

```sql
SELECT
  je.tenant_id,
  EXTRACT(YEAR FROM je.entry_date) as fiscal_year,
  coa.account_type,
  coa.account_code,
  coa.account_name,
  SUM(jel.debit_amount - jel.credit_amount) as balance
FROM journal_entries je
JOIN journal_entry_lines jel ON je.entry_id = jel.entry_id
JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
WHERE je.status = 'posted'
  AND coa.account_type IN ('Asset', 'Liability', 'Equity')
GROUP BY je.tenant_id, fiscal_year, coa.account_type, coa.account_code, coa.account_name;
```

### 4. cash_position (View)

```sql
SELECT
  ba.tenant_id,
  ba.bank_account_id,
  ba.account_name,
  ba.currency,
  ba.current_balance,
  ba.available_balance,
  SUM(CASE WHEN bt.transaction_date >= CURRENT_DATE AND bt.credit_amount > 0
    THEN bt.credit_amount ELSE 0 END) as todays_inflows,
  SUM(CASE WHEN bt.transaction_date >= CURRENT_DATE AND bt.debit_amount > 0
    THEN bt.debit_amount ELSE 0 END) as todays_outflows
FROM bank_accounts ba
LEFT JOIN bank_transactions bt ON ba.bank_account_id = bt.bank_account_id
WHERE ba.status = 'active'
GROUP BY ba.tenant_id, ba.bank_account_id, ba.account_name, ba.currency,
         ba.current_balance, ba.available_balance;
```

---

## Testing Queries Directly

You can test these queries directly in PostgreSQL:

```sql
-- Set variables
\set tenant_id '00000000-0000-0000-0000-000000000001'
\set vendor_id '20000000-0000-0000-0000-000000000001'

-- Test Vendor Ledger Query
SELECT
  ai.invoice_id,
  ai.invoice_number,
  ai.invoice_date,
  ai.due_date,
  ai.subtotal,
  ai.tax_amount,
  ai.total_amount,
  ai.amount_paid,
  ai.amount_outstanding,
  ai.status,
  ai.payment_status,
  v.vendor_name,
  v.vendor_code
FROM ap_invoices ai
JOIN vendors v ON ai.vendor_id = v.vendor_id
WHERE ai.tenant_id = :'tenant_id'::uuid
  AND ai.vendor_id = :'vendor_id'::uuid
ORDER BY ai.invoice_date ASC, ai.created_at ASC;
```

---

## Accounting Logic Reference

### Double-Entry Bookkeeping Rules

**Normal Balances:**
- **Assets**: Debit (increase with debits)
- **Liabilities**: Credit (increase with credits)
- **Equity**: Credit (increase with credits)
- **Revenue**: Credit (increase with credits)
- **Expenses**: Debit (increase with debits)

**Balance Calculations:**
- **Assets**: Debit Amount - Credit Amount
- **Liabilities**: Credit Amount - Debit Amount
- **Equity**: Credit Amount - Debit Amount
- **Revenue**: Credit Amount - Debit Amount
- **Expenses**: Debit Amount - Credit Amount

**Financial Statement Equations:**
- **Balance Sheet**: Assets = Liabilities + Equity
- **Income Statement**: Net Income = Revenue - Expenses
- **Cash Flow**: Closing Balance = Opening Balance + Inflows - Outflows

---

**Document Version:** 1.0
**Last Updated:** October 19, 2025
**Database:** PostgreSQL 15+
**Schema:** airp_master
