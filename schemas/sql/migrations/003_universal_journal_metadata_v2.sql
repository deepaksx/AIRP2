-- =====================================================
-- Migration 003: Universal Journal with JSONB Metadata (v2)
-- =====================================================
-- Description: Enhance journal_entry_lines to become Universal Journal
--              Archive existing ap_invoices/ar_invoices tables
--              All new invoices will use metadata field
-- Date: 2025-10-21
-- Version: v2.12.0
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Add metadata JSONB field (if not exists)
-- =====================================================

-- metadata field already exists from AI Context migration
-- Just ensure indexes are in place

CREATE INDEX IF NOT EXISTS idx_jel_metadata_gin
ON journal_entry_lines USING GIN (metadata jsonb_path_ops);

CREATE INDEX IF NOT EXISTS idx_jel_metadata_invoice_number
ON journal_entry_lines ((metadata->>'invoice_number'))
WHERE metadata->>'invoice_number' IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_jel_metadata_payment_status
ON journal_entry_lines ((metadata->>'payment_status'))
WHERE metadata->>'payment_status' IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_jel_metadata_due_date
ON journal_entry_lines ((metadata->>'due_date'))
WHERE metadata->>'due_date' IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_jel_metadata_source_type
ON journal_entry_lines ((metadata->>'source_type'))
WHERE metadata->>'source_type' IS NOT NULL;

-- =====================================================
-- STEP 2: Create helper functions
-- =====================================================

-- Function to calculate days outstanding
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

-- Function to calculate aging bucket
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

-- =====================================================
-- STEP 3: Create views for AP/AR invoices
-- =====================================================

-- Drop existing views if they exist
DROP VIEW IF EXISTS vw_ap_invoices CASCADE;
DROP VIEW IF EXISTS vw_ar_invoices CASCADE;

-- Create AP Invoices view from journal_entry_lines
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
WHERE coa.account_code = '2100'  -- AP control account
  AND jel.metadata->>'source_type' = 'ap_invoice'
  AND jel.dimension_1 IS NOT NULL;

-- Create AR Invoices view from journal_entry_lines
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
WHERE coa.account_code = '1200'  -- AR control account
  AND jel.metadata->>'source_type' = 'ar_invoice'
  AND jel.dimension_2 IS NOT NULL;

-- =====================================================
-- STEP 4: Create materialized views for aging reports
-- =====================================================

DROP MATERIALIZED VIEW IF EXISTS mv_ar_aging CASCADE;

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

DROP MATERIALIZED VIEW IF EXISTS mv_ap_aging CASCADE;

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

-- =====================================================
-- STEP 5: Archive old tables (rename, don't drop)
-- =====================================================

-- Rename tables to archive (keeps data for audit/reference)
ALTER TABLE IF EXISTS ap_invoices RENAME TO ap_invoices_legacy_archived;
ALTER TABLE IF EXISTS ar_invoices RENAME TO ar_invoices_legacy_archived;

-- Rename related tables
ALTER TABLE IF EXISTS ap_aging RENAME TO ap_aging_legacy_archived;
ALTER TABLE IF EXISTS ar_aging RENAME TO ar_aging_legacy_archived;
ALTER TABLE IF EXISTS ap_invoice_lines RENAME TO ap_invoice_lines_legacy_archived;
ALTER TABLE IF EXISTS ar_invoice_lines RENAME TO ar_invoice_lines_legacy_archived;

-- Add archive timestamp
ALTER TABLE IF EXISTS ap_invoices_legacy_archived
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE IF EXISTS ar_invoices_legacy_archived
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- =====================================================
-- STEP 6: Grant permissions
-- =====================================================

GRANT SELECT ON vw_ap_invoices TO PUBLIC;
GRANT SELECT ON vw_ar_invoices TO PUBLIC;
GRANT SELECT ON mv_ap_aging TO PUBLIC;
GRANT SELECT ON mv_ar_aging TO PUBLIC;

-- =====================================================
-- STEP 7: Add comments
-- =====================================================

COMMENT ON COLUMN journal_entry_lines.metadata IS
'Universal Journal metadata field. Stores invoice details (invoice_number, due_date, payment_terms, etc.), AI context, and other business data. Similar to SAP ACDOCA table.';

COMMENT ON VIEW vw_ap_invoices IS
'AP Invoices view from Universal Journal (journal_entry_lines.metadata). Replaces ap_invoices table.';

COMMENT ON VIEW vw_ar_invoices IS
'AR Invoices view from Universal Journal (journal_entry_lines.metadata). Replaces ar_invoices table.';

COMMENT ON MATERIALIZED VIEW mv_ap_aging IS
'Materialized AP Aging Report. Refresh: REFRESH MATERIALIZED VIEW mv_ap_aging;';

COMMENT ON MATERIALIZED VIEW mv_ar_aging IS
'Materialized AR Aging Report. Refresh: REFRESH MATERIALIZED VIEW mv_ar_aging;';

COMMENT ON FUNCTION calculate_days_outstanding IS
'Returns days outstanding from metadata due_date field.';

COMMENT ON FUNCTION calculate_aging_bucket IS
'Returns aging bucket: Not Due, 1-30 days, 31-60 days, 61-90 days, 90+ days.';

-- =====================================================
-- Verification
-- =====================================================

DO $$
DECLARE
    v_jel_count INTEGER;
    v_metadata_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_jel_count FROM journal_entry_lines;
    SELECT COUNT(*) INTO v_metadata_count
    FROM journal_entry_lines
    WHERE metadata IS NOT NULL AND jsonb_typeof(metadata) = 'object';

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Universal Journal Migration Complete';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total journal_entry_lines: %', v_jel_count;
    RAISE NOTICE 'Lines with metadata: %', v_metadata_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Views created:';
    RAISE NOTICE '  - vw_ap_invoices';
    RAISE NOTICE '  - vw_ar_invoices';
    RAISE NOTICE '  - mv_ap_aging (materialized)';
    RAISE NOTICE '  - mv_ar_aging (materialized)';
    RAISE NOTICE '';
    RAISE NOTICE 'Legacy tables archived:';
    RAISE NOTICE '  - ap_invoices → ap_invoices_legacy_archived';
    RAISE NOTICE '  - ar_invoices → ar_invoices_legacy_archived';
    RAISE NOTICE '  - ap_aging → ap_aging_legacy_archived';
    RAISE NOTICE '  - ar_aging → ar_aging_legacy_archived';
    RAISE NOTICE '';
    RAISE NOTICE 'All new invoices will use journal_entry_lines.metadata';
    RAISE NOTICE '========================================';
END $$;

COMMIT;

-- =====================================================
-- Rollback Script
-- =====================================================
-- BEGIN;
-- DROP MATERIALIZED VIEW IF EXISTS mv_ar_aging CASCADE;
-- DROP MATERIALIZED VIEW IF EXISTS mv_ap_aging CASCADE;
-- DROP VIEW IF EXISTS vw_ar_invoices CASCADE;
-- DROP VIEW IF EXISTS vw_ap_invoices CASCADE;
-- DROP FUNCTION IF EXISTS calculate_aging_bucket;
-- DROP FUNCTION IF EXISTS calculate_days_outstanding;
-- ALTER TABLE ap_invoices_legacy_archived RENAME TO ap_invoices;
-- ALTER TABLE ar_invoices_legacy_archived RENAME TO ar_invoices;
-- ALTER TABLE ap_aging_legacy_archived RENAME TO ap_aging;
-- ALTER TABLE ar_aging_legacy_archived RENAME TO ar_aging;
-- ALTER TABLE ap_invoice_lines_legacy_archived RENAME TO ap_invoice_lines;
-- ALTER TABLE ar_invoice_lines_legacy_archived RENAME TO ar_invoice_lines;
-- DROP INDEX IF EXISTS idx_jel_metadata_gin;
-- DROP INDEX IF EXISTS idx_jel_metadata_invoice_number;
-- DROP INDEX IF EXISTS idx_jel_metadata_payment_status;
-- DROP INDEX IF EXISTS idx_jel_metadata_due_date;
-- DROP INDEX IF EXISTS idx_jel_metadata_source_type;
-- COMMIT;
