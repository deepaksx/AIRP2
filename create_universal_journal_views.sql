-- Create Universal Journal Views

DROP VIEW IF EXISTS vw_ap_invoices CASCADE;
DROP VIEW IF EXISTS vw_ar_invoices CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_ap_aging CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_ar_aging CASCADE;

-- AP Invoices view
CREATE VIEW vw_ap_invoices AS
SELECT
    jel.line_id as invoice_id,
    jel.tenant_id,
    jel.dimension_1::uuid as vendor_id,
    jel.metadata->>'invoice_number' as invoice_number,
    (jel.metadata->>'invoice_date')::date as invoice_date,
    (jel.metadata->>'due_date')::date as due_date,
    jel.metadata->>'payment_terms' as payment_terms,
    (jel.metadata->>'total_amount')::numeric as total_amount,
    COALESCE((jel.metadata->>'amount_paid')::numeric, 0) as amount_paid,
    COALESCE((jel.metadata->>'amount_outstanding')::numeric, jel.credit_amount) as amount_outstanding,
    COALESCE(jel.metadata->>'currency', 'AED') as currency,
    (jel.metadata->>'subtotal')::numeric as subtotal,
    (jel.metadata->>'tax_amount')::numeric as tax_amount,
    COALESCE(jel.metadata->>'payment_status', 'unpaid') as payment_status,
    jel.metadata->>'status' as status,
    jel.entry_id as gl_entry_id,
    jel.metadata,
    calculate_days_outstanding(jel.metadata) as days_outstanding,
    calculate_aging_bucket(jel.metadata) as aging_bucket,
    je.entry_date as posting_date,
    je.created_at,
    je.updated_at
FROM journal_entry_lines jel
JOIN journal_entries je ON jel.entry_id = je.entry_id
JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
WHERE coa.account_code = '2100'
  AND jel.metadata->>'source_type' = 'ap_invoice'
  AND jel.dimension_1 IS NOT NULL;

-- AR Invoices view
CREATE VIEW vw_ar_invoices AS
SELECT
    jel.line_id as invoice_id,
    jel.tenant_id,
    jel.dimension_2::uuid as customer_id,
    jel.metadata->>'invoice_number' as invoice_number,
    (jel.metadata->>'invoice_date')::date as invoice_date,
    (jel.metadata->>'due_date')::date as due_date,
    jel.metadata->>'payment_terms' as payment_terms,
    (jel.metadata->>'total_amount')::numeric as total_amount,
    COALESCE((jel.metadata->>'amount_paid')::numeric, 0) as amount_paid,
    COALESCE((jel.metadata->>'amount_outstanding')::numeric, jel.debit_amount) as amount_outstanding,
    COALESCE(jel.metadata->>'currency', 'AED') as currency,
    (jel.metadata->>'subtotal')::numeric as subtotal,
    (jel.metadata->>'tax_amount')::numeric as tax_amount,
    COALESCE(jel.metadata->>'payment_status', 'unpaid') as payment_status,
    jel.metadata->>'status' as status,
    jel.entry_id as gl_entry_id,
    jel.metadata,
    calculate_days_outstanding(jel.metadata) as days_outstanding,
    calculate_aging_bucket(jel.metadata) as aging_bucket,
    je.entry_date as posting_date,
    je.created_at,
    je.updated_at
FROM journal_entry_lines jel
JOIN journal_entries je ON jel.entry_id = je.entry_id
JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
WHERE coa.account_code = '1200'
  AND jel.metadata->>'source_type' = 'ar_invoice'
  AND jel.dimension_2 IS NOT NULL;

-- AP Aging materialized view
CREATE MATERIALIZED VIEW mv_ap_aging AS
SELECT
    v.tenant_id,
    v.vendor_id,
    vn.vendor_code,
    vn.vendor_name,
    vn.payment_terms as default_payment_terms,
    v.invoice_number,
    v.invoice_date,
    v.due_date,
    v.payment_terms,
    v.amount_outstanding,
    v.days_outstanding,
    v.aging_bucket,
    v.gl_entry_id
FROM vw_ap_invoices v
JOIN vendors vn ON v.vendor_id = vn.vendor_id
WHERE v.payment_status IN ('unpaid', 'partial')
  AND v.amount_outstanding > 0
ORDER BY vn.vendor_name, v.due_date;

CREATE INDEX idx_mv_ap_aging_tenant ON mv_ap_aging(tenant_id);
CREATE INDEX idx_mv_ap_aging_vendor ON mv_ap_aging(vendor_id);
CREATE INDEX idx_mv_ap_aging_bucket ON mv_ap_aging(aging_bucket);

-- AR Aging materialized view
CREATE MATERIALIZED VIEW mv_ar_aging AS
SELECT
    v.tenant_id,
    v.customer_id,
    c.customer_code,
    c.customer_name,
    c.payment_terms as default_payment_terms,
    v.invoice_number,
    v.invoice_date,
    v.due_date,
    v.payment_terms,
    v.amount_outstanding,
    v.days_outstanding,
    v.aging_bucket,
    v.gl_entry_id
FROM vw_ar_invoices v
JOIN customers c ON v.customer_id = c.customer_id
WHERE v.payment_status IN ('unpaid', 'partial')
  AND v.amount_outstanding > 0
ORDER BY c.customer_name, v.due_date;

CREATE INDEX idx_mv_ar_aging_tenant ON mv_ar_aging(tenant_id);
CREATE INDEX idx_mv_ar_aging_customer ON mv_ar_aging(customer_id);
CREATE INDEX idx_mv_ar_aging_bucket ON mv_ar_aging(aging_bucket);

GRANT SELECT ON vw_ap_invoices TO PUBLIC;
GRANT SELECT ON vw_ar_invoices TO PUBLIC;
GRANT SELECT ON mv_ap_aging TO PUBLIC;
GRANT SELECT ON mv_ar_aging TO PUBLIC;

SELECT 'Universal Journal views and materialized views created' as status;
