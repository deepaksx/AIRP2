-- =====================================================
-- Migration 003: Universal Journal with JSONB Metadata
-- =====================================================
-- Description: Enhance journal_entry_lines to become Universal Journal
--              Store all sub-ledger details in JSONB metadata field
--              Remove dependency on ap_invoices and ar_invoices tables
-- Date: 2025-10-21
-- Version: v2.12.0
-- =====================================================

BEGIN;

-- =====================================================
-- STEP 1: Add metadata columns to journal_entry_lines
-- =====================================================

-- Add comprehensive metadata JSONB field
ALTER TABLE journal_entry_lines
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Create GIN index for fast JSONB queries
CREATE INDEX IF NOT EXISTS idx_jel_metadata_gin
ON journal_entry_lines USING GIN (metadata jsonb_path_ops);

-- Create specialized indexes for common queries
CREATE INDEX IF NOT EXISTS idx_jel_metadata_invoice_number
ON journal_entry_lines ((metadata->>'invoice_number'))
WHERE metadata->>'invoice_number' IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_jel_metadata_payment_status
ON journal_entry_lines ((metadata->>'payment_status'))
WHERE metadata->>'payment_status' IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_jel_metadata_due_date
ON journal_entry_lines ((metadata->>'due_date'))
WHERE metadata->>'due_date' IS NOT NULL;

-- =====================================================
-- STEP 2: Migrate existing ap_invoices data to metadata
-- =====================================================

UPDATE journal_entry_lines jel
SET metadata = metadata || jsonb_build_object(
    'invoice_number', api.invoice_number,
    'invoice_date', api.invoice_date::text,
    'due_date', api.due_date::text,
    'payment_terms', api.payment_terms,
    'payment_status', api.payment_status,
    'total_amount', api.total_amount,
    'amount_paid', api.amount_paid,
    'amount_outstanding', api.amount_outstanding,
    'currency', api.currency,
    'subtotal', api.subtotal,
    'tax_amount', api.tax_amount,
    'status', api.status,
    'source_type', 'ap_invoice',
    'vendor_id', api.vendor_id::text,
    'po_number', api.metadata->>'po_number',
    'approval_status', api.metadata->>'approval_status',
    'notes', api.metadata->>'notes'
)
FROM ap_invoices api
JOIN journal_entries je ON api.gl_entry_id = je.entry_id
WHERE jel.entry_id = je.entry_id
  AND jel.dimension_1 = api.vendor_id
  AND api.gl_entry_id IS NOT NULL;

-- =====================================================
-- STEP 3: Migrate existing ar_invoices data to metadata
-- =====================================================

UPDATE journal_entry_lines jel
SET metadata = metadata || jsonb_build_object(
    'invoice_number', ari.invoice_number,
    'invoice_date', ari.invoice_date::text,
    'due_date', ari.due_date::text,
    'payment_terms', ari.payment_terms,
    'payment_status', ari.payment_status,
    'total_amount', ari.total_amount,
    'amount_paid', ari.amount_paid,
    'amount_outstanding', ari.amount_outstanding,
    'currency', ari.currency,
    'subtotal', ari.subtotal,
    'tax_amount', ari.tax_amount,
    'status', ari.status,
    'source_type', 'ar_invoice',
    'customer_id', ari.customer_id::text,
    'po_number', ari.metadata->>'po_number',
    'approval_status', ari.metadata->>'approval_status',
    'notes', ari.metadata->>'notes'
)
FROM ar_invoices ari
JOIN journal_entries je ON ari.gl_entry_id = je.entry_id
WHERE jel.entry_id = je.entry_id
  AND jel.dimension_2 = ari.customer_id
  AND ari.gl_entry_id IS NOT NULL;

-- =====================================================
-- STEP 4: Create calculated fields for aging
-- =====================================================

-- Add function to calculate days outstanding
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

-- Add function to calculate aging bucket
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
-- STEP 5: Create views to replace ap_invoices/ar_invoices
-- =====================================================

-- Drop existing views if they exist
DROP VIEW IF EXISTS vw_ap_invoices CASCADE;
DROP VIEW IF EXISTS vw_ar_invoices CASCADE;

-- Create AP Invoices view
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
    (jel.metadata->>'amount_paid')::numeric as amount_paid,
    (jel.metadata->>'amount_outstanding')::numeric as amount_outstanding,
    jel.metadata->>'currency' as currency,
    (jel.metadata->>'subtotal')::numeric as subtotal,
    (jel.metadata->>'tax_amount')::numeric as tax_amount,
    jel.metadata->>'payment_status' as payment_status,
    jel.metadata->>'status' as status,
    jel.entry_id as gl_entry_id,
    jel.metadata as metadata,
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

-- Create AR Invoices view
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
    (jel.metadata->>'amount_paid')::numeric as amount_paid,
    (jel.metadata->>'amount_outstanding')::numeric as amount_outstanding,
    jel.metadata->>'currency' as currency,
    (jel.metadata->>'subtotal')::numeric as subtotal,
    (jel.metadata->>'tax_amount')::numeric as tax_amount,
    jel.metadata->>'payment_status' as payment_status,
    jel.metadata->>'status' as status,
    jel.entry_id as gl_entry_id,
    jel.metadata as metadata,
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
-- STEP 6: Create materialized view for AR Aging Report
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

-- Create index on materialized view
CREATE INDEX idx_mv_ar_aging_tenant ON mv_ar_aging(tenant_id);
CREATE INDEX idx_mv_ar_aging_customer ON mv_ar_aging(customer_id);
CREATE INDEX idx_mv_ar_aging_bucket ON mv_ar_aging(aging_bucket);

-- =====================================================
-- STEP 7: Create materialized view for AP Aging Report
-- =====================================================

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

-- Create index on materialized view
CREATE INDEX idx_mv_ap_aging_tenant ON mv_ap_aging(tenant_id);
CREATE INDEX idx_mv_ap_aging_vendor ON mv_ap_aging(vendor_id);
CREATE INDEX idx_mv_ap_aging_bucket ON mv_ap_aging(aging_bucket);

-- =====================================================
-- STEP 8: Archive old tables (DO NOT DROP - keep for audit)
-- =====================================================

-- Rename tables to archive (keep data for audit trail)
ALTER TABLE IF EXISTS ap_invoices RENAME TO ap_invoices_archive_20251021;
ALTER TABLE IF EXISTS ar_invoices RENAME TO ar_invoices_archive_20251021;

-- Add archive timestamp columns
ALTER TABLE IF EXISTS ap_invoices_archive_20251021
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE IF EXISTS ar_invoices_archive_20251021
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- =====================================================
-- STEP 9: Grant permissions
-- =====================================================

-- Grant permissions on views
GRANT SELECT ON vw_ap_invoices TO PUBLIC;
GRANT SELECT ON vw_ar_invoices TO PUBLIC;
GRANT SELECT ON mv_ap_aging TO PUBLIC;
GRANT SELECT ON mv_ar_aging TO PUBLIC;

-- =====================================================
-- STEP 10: Add comments for documentation
-- =====================================================

COMMENT ON COLUMN journal_entry_lines.metadata IS
'JSONB field containing all sub-ledger details: invoice_number, due_date, payment_terms, payment_status, etc. This implements Universal Journal architecture similar to SAP ACDOCA.';

COMMENT ON VIEW vw_ap_invoices IS
'Virtual view of AP invoices from Universal Journal (journal_entry_lines.metadata). Replaces ap_invoices table.';

COMMENT ON VIEW vw_ar_invoices IS
'Virtual view of AR invoices from Universal Journal (journal_entry_lines.metadata). Replaces ar_invoices table.';

COMMENT ON MATERIALIZED VIEW mv_ap_aging IS
'Materialized view for AP Aging Report. Refresh with: REFRESH MATERIALIZED VIEW mv_ap_aging;';

COMMENT ON MATERIALIZED VIEW mv_ar_aging IS
'Materialized view for AR Aging Report. Refresh with: REFRESH MATERIALIZED VIEW mv_ar_aging;';

COMMENT ON FUNCTION calculate_days_outstanding IS
'Calculates days outstanding from metadata due_date. Returns NULL if no due date.';

COMMENT ON FUNCTION calculate_aging_bucket IS
'Calculates aging bucket (Not Due, 1-30 days, 31-60 days, 61-90 days, 90+ days) from metadata due_date.';

-- =====================================================
-- Verification Queries
-- =====================================================

-- Count records migrated
DO $$
DECLARE
    ap_count INTEGER;
    ar_count INTEGER;
    metadata_ap_count INTEGER;
    metadata_ar_count INTEGER;
BEGIN
    -- Count archived AP invoices
    SELECT COUNT(*) INTO ap_count FROM ap_invoices_archive_20251021;

    -- Count archived AR invoices
    SELECT COUNT(*) INTO ar_count FROM ar_invoices_archive_20251021;

    -- Count AP metadata records
    SELECT COUNT(*) INTO metadata_ap_count
    FROM journal_entry_lines
    WHERE metadata->>'source_type' = 'ap_invoice';

    -- Count AR metadata records
    SELECT COUNT(*) INTO metadata_ar_count
    FROM journal_entry_lines
    WHERE metadata->>'source_type' = 'ar_invoice';

    RAISE NOTICE 'Migration Summary:';
    RAISE NOTICE '  AP Invoices archived: %', ap_count;
    RAISE NOTICE '  AR Invoices archived: %', ar_count;
    RAISE NOTICE '  AP metadata records: %', metadata_ap_count;
    RAISE NOTICE '  AR metadata records: %', metadata_ar_count;
END $$;

COMMIT;

-- =====================================================
-- Rollback Script (Save separately!)
-- =====================================================

-- To rollback this migration:
-- BEGIN;
-- DROP MATERIALIZED VIEW IF EXISTS mv_ar_aging CASCADE;
-- DROP MATERIALIZED VIEW IF EXISTS mv_ap_aging CASCADE;
-- DROP VIEW IF EXISTS vw_ar_invoices CASCADE;
-- DROP VIEW IF EXISTS vw_ap_invoices CASCADE;
-- DROP FUNCTION IF EXISTS calculate_aging_bucket;
-- DROP FUNCTION IF EXISTS calculate_days_outstanding;
-- ALTER TABLE ap_invoices_archive_20251021 RENAME TO ap_invoices;
-- ALTER TABLE ar_invoices_archive_20251021 RENAME TO ar_invoices;
-- ALTER TABLE ap_invoices DROP COLUMN IF EXISTS archived_at;
-- ALTER TABLE ar_invoices DROP COLUMN IF EXISTS archived_at;
-- DROP INDEX IF EXISTS idx_jel_metadata_gin;
-- DROP INDEX IF EXISTS idx_jel_metadata_invoice_number;
-- DROP INDEX IF EXISTS idx_jel_metadata_payment_status;
-- DROP INDEX IF EXISTS idx_jel_metadata_due_date;
-- ALTER TABLE journal_entry_lines DROP COLUMN IF EXISTS metadata;
-- COMMIT;
