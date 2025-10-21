-- =====================================================
-- Migration 004: Clean Slate + Universal Journal Setup
-- =====================================================
-- Description: Delete all transaction data, set up Universal Journal
-- Date: 2025-10-21
-- Version: v2.12.0
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Delete all transaction data
-- =====================================================

-- Delete journal entries (cascades to journal_entry_lines)
DELETE FROM journal_entry_lines;
DELETE FROM journal_entries;

-- Delete sub-ledger data
DELETE FROM ap_invoices;
DELETE FROM ar_invoices;
DELETE FROM ap_invoice_lines WHERE TRUE;
DELETE FROM ar_invoice_lines WHERE TRUE;
DELETE FROM ap_aging WHERE TRUE;
DELETE FROM ar_aging WHERE TRUE;

-- Delete GL balances
DELETE FROM gl_balances;

-- Reset sequences (if any)
-- journal_entry_lines and journal_entries use UUIDs, no sequences to reset

RAISE NOTICE 'All transaction data deleted';

-- =====================================================
-- STEP 2: Archive and remove legacy tables
-- =====================================================

-- Drop legacy sub-ledger tables completely
DROP TABLE IF EXISTS ap_invoice_lines CASCADE;
DROP TABLE IF EXISTS ar_invoice_lines CASCADE;
DROP TABLE IF EXISTS ap_aging CASCADE;
DROP TABLE IF EXISTS ar_aging CASCADE;
DROP TABLE IF EXISTS ap_invoices CASCADE;
DROP TABLE IF EXISTS ar_invoices CASCADE;

RAISE NOTICE 'Legacy sub-ledger tables removed';

-- =====================================================
-- STEP 3: Enhance journal_entry_lines for Universal Journal
-- =====================================================

-- Ensure metadata column exists
ALTER TABLE journal_entry_lines
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Create comprehensive indexes for Universal Journal
DROP INDEX IF EXISTS idx_jel_metadata_gin;
DROP INDEX IF EXISTS idx_jel_metadata_invoice_number;
DROP INDEX IF EXISTS idx_jel_metadata_payment_status;
DROP INDEX IF EXISTS idx_jel_metadata_due_date;
DROP INDEX IF EXISTS idx_jel_metadata_source_type;

CREATE INDEX idx_jel_metadata_gin
ON journal_entry_lines USING GIN (metadata jsonb_path_ops);

CREATE INDEX idx_jel_metadata_invoice_number
ON journal_entry_lines ((metadata->>'invoice_number'))
WHERE metadata->>'invoice_number' IS NOT NULL;

CREATE INDEX idx_jel_metadata_payment_status
ON journal_entry_lines ((metadata->>'payment_status'))
WHERE metadata->>'payment_status' IS NOT NULL;

CREATE INDEX idx_jel_metadata_due_date
ON journal_entry_lines ((metadata->>'due_date'))
WHERE metadata->>'due_date' IS NOT NULL;

CREATE INDEX idx_jel_metadata_source_type
ON journal_entry_lines ((metadata->>'source_type'))
WHERE metadata->>'source_type' IS NOT NULL;

RAISE NOTICE 'Universal Journal indexes created';

-- =====================================================
-- STEP 4: Create helper functions
-- =====================================================

DROP FUNCTION IF EXISTS calculate_days_outstanding CASCADE;
DROP FUNCTION IF EXISTS calculate_aging_bucket CASCADE;

CREATE OR REPLACE FUNCTION calculate_days_outstanding(metadata JSONB)
RETURNS INTEGER AS $$
BEGIN
    IF metadata->>'due_date' IS NOT NULL THEN
        RETURN CURRENT_DATE - (metadata->>'due_date')::DATE;
    ELSE
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION calculate_aging_bucket(metadata JSONB)
RETURNS VARCHAR(20) AS $$
DECLARE
    days_outstanding INTEGER;
BEGIN
    days_outstanding := calculate_days_outstanding(metadata);

    IF days_outstanding IS NULL THEN
        RETURN NULL;
    ELSIF days_outstanding <= 0 THEN
        RETURN 'Not Due';
    ELSIF days_outstanding <= 30 THEN
        RETURN '1-30 days';
    ELSIF days_outstanding <= 60 THEN
        RETURN '31-60 days';
    ELSIF days_outstanding <= 90 THEN
        RETURN '61-90 days';
    ELSE
        RETURN '90+ days';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

RAISE NOTICE 'Helper functions created';

-- =====================================================
-- STEP 5: Create Universal Journal views
-- =====================================================

DROP VIEW IF EXISTS vw_ap_invoices CASCADE;
DROP VIEW IF EXISTS vw_ar_invoices CASCADE;

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

RAISE NOTICE 'Universal Journal views created';

-- =====================================================
-- STEP 6: Create materialized views for aging
-- =====================================================

DROP MATERIALIZED VIEW IF EXISTS mv_ar_aging CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_ap_aging CASCADE;

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

RAISE NOTICE 'Materialized views for aging created';

-- =====================================================
-- STEP 7: Refresh trial balance materialized view
-- =====================================================

REFRESH MATERIALIZED VIEW trial_balance;

RAISE NOTICE 'Trial balance refreshed';

-- =====================================================
-- STEP 8: Grant permissions
-- =====================================================

GRANT SELECT ON vw_ap_invoices TO PUBLIC;
GRANT SELECT ON vw_ar_invoices TO PUBLIC;
GRANT SELECT ON mv_ap_aging TO PUBLIC;
GRANT SELECT ON mv_ar_aging TO PUBLIC;

-- =====================================================
-- STEP 9: Add comments
-- =====================================================

COMMENT ON COLUMN journal_entry_lines.metadata IS
'Universal Journal metadata. Structure: {
  "source_type": "ap_invoice|ar_invoice|payment|adjustment",
  "invoice_number": "INV-2025-001",
  "invoice_date": "2025-10-20",
  "due_date": "2025-11-20",
  "payment_terms": "Net 30",
  "payment_status": "unpaid|partial|paid",
  "total_amount": 1050.00,
  "amount_paid": 0.00,
  "amount_outstanding": 1050.00,
  "subtotal": 1000.00,
  "tax_amount": 50.00,
  "currency": "AED",
  "po_number": "PO-12345",
  "notes": "Additional information"
}';

COMMENT ON VIEW vw_ap_invoices IS
'Virtual AP Invoices from Universal Journal. Replaces ap_invoices table.';

COMMENT ON VIEW vw_ar_invoices IS
'Virtual AR Invoices from Universal Journal. Replaces ar_invoices table.';

-- =====================================================
-- Summary
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Clean Slate + Universal Journal Setup';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Status: COMPLETE';
    RAISE NOTICE '';
    RAISE NOTICE 'Changes:';
    RAISE NOTICE '  ✅ All transaction data deleted';
    RAISE NOTICE '  ✅ Legacy tables removed (ap_invoices, ar_invoices)';
    RAISE NOTICE '  ✅ Universal Journal structure created';
    RAISE NOTICE '  ✅ Views created (vw_ap_invoices, vw_ar_invoices)';
    RAISE NOTICE '  ✅ Materialized aging views created';
    RAISE NOTICE '  ✅ Helper functions created';
    RAISE NOTICE '  ✅ Indexes optimized';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Step:';
    RAISE NOTICE '  Load comprehensive test data (100+ transactions)';
    RAISE NOTICE '========================================';
END $$;

COMMIT;
