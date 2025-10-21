-- ============================================
-- AIRP v2.11.0 - AI Context Metadata Migration
-- Adds AI-generated context fields to all tables
-- for intelligent natural language querying
-- ============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For similarity search
CREATE EXTENSION IF NOT EXISTS "btree_gin"; -- For JSONB indexing

-- ============================================
-- MASTER DATA TABLES - Add Context Fields
-- ============================================

-- Chart of Accounts
ALTER TABLE chart_of_accounts ADD COLUMN IF NOT EXISTS ai_context_summary TEXT;
ALTER TABLE chart_of_accounts ADD COLUMN IF NOT EXISTS ai_context_keywords TEXT[];
ALTER TABLE chart_of_accounts ADD COLUMN IF NOT EXISTS ai_context_entities JSONB;
ALTER TABLE chart_of_accounts ADD COLUMN IF NOT EXISTS ai_context_relationships JSONB;
ALTER TABLE chart_of_accounts ADD COLUMN IF NOT EXISTS ai_context_generated_at TIMESTAMPTZ;
ALTER TABLE chart_of_accounts ADD COLUMN IF NOT EXISTS ai_context_model_version VARCHAR(50);

COMMENT ON COLUMN chart_of_accounts.ai_context_summary IS 'AI-generated plain English description of account purpose and typical usage';
COMMENT ON COLUMN chart_of_accounts.ai_context_keywords IS 'Searchable keywords for semantic search (e.g., "rent", "lease", "property")';
COMMENT ON COLUMN chart_of_accounts.ai_context_entities IS 'Extracted entities: account usage patterns, typical amounts, frequency';
COMMENT ON COLUMN chart_of_accounts.ai_context_relationships IS 'Related vendors/customers that commonly use this account';

-- Vendors
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS ai_context_summary TEXT;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS ai_context_keywords TEXT[];
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS ai_context_entities JSONB;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS ai_context_relationships JSONB;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS ai_context_generated_at TIMESTAMPTZ;
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS ai_context_model_version VARCHAR(50);

COMMENT ON COLUMN vendors.ai_context_summary IS 'AI-generated vendor profile: business type, products/services, relationship history';
COMMENT ON COLUMN vendors.ai_context_keywords IS 'Searchable keywords for vendor discovery (e.g., "office supplies", "IT equipment")';
COMMENT ON COLUMN vendors.ai_context_entities IS 'Vendor classification, typical transaction patterns, payment behavior';
COMMENT ON COLUMN vendors.ai_context_relationships IS 'Frequently used GL accounts, average invoice amounts, transaction frequency';

-- Customers
ALTER TABLE customers ADD COLUMN IF NOT EXISTS ai_context_summary TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS ai_context_keywords TEXT[];
ALTER TABLE customers ADD COLUMN IF NOT EXISTS ai_context_entities JSONB;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS ai_context_relationships JSONB;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS ai_context_generated_at TIMESTAMPTZ;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS ai_context_model_version VARCHAR(50);

COMMENT ON COLUMN customers.ai_context_summary IS 'AI-generated customer profile: business type, products/services purchased, payment history';
COMMENT ON COLUMN customers.ai_context_keywords IS 'Searchable keywords for customer discovery';
COMMENT ON COLUMN customers.ai_context_entities IS 'Customer classification, buying patterns, payment behavior';
COMMENT ON COLUMN customers.ai_context_relationships IS 'Frequently used revenue accounts, average invoice amounts, transaction frequency';

-- ============================================
-- TRANSACTION TABLES - Add Context Fields
-- ============================================

-- Journal Entries
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS ai_context_summary TEXT;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS ai_context_keywords TEXT[];
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS ai_context_entities JSONB;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS ai_context_relationships JSONB;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS ai_context_generated_at TIMESTAMPTZ;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS ai_context_model_version VARCHAR(50);

COMMENT ON COLUMN journal_entries.ai_context_summary IS 'AI-generated transaction summary: business purpose, nature, and impact';
COMMENT ON COLUMN journal_entries.ai_context_keywords IS 'Searchable keywords for transaction discovery (e.g., "rent payment", "salary")';
COMMENT ON COLUMN journal_entries.ai_context_entities IS 'Transaction classification, involved parties, business purpose';
COMMENT ON COLUMN journal_entries.ai_context_relationships IS 'Related vendors/customers, linked invoices, recurring pattern indicator';

-- AP Invoices
ALTER TABLE ap_invoices ADD COLUMN IF NOT EXISTS ai_context_summary TEXT;
ALTER TABLE ap_invoices ADD COLUMN IF NOT EXISTS ai_context_keywords TEXT[];
ALTER TABLE ap_invoices ADD COLUMN IF NOT EXISTS ai_context_entities JSONB;
ALTER TABLE ap_invoices ADD COLUMN IF NOT EXISTS ai_context_relationships JSONB;
ALTER TABLE ap_invoices ADD COLUMN IF NOT EXISTS ai_context_generated_at TIMESTAMPTZ;
ALTER TABLE ap_invoices ADD COLUMN IF NOT EXISTS ai_context_model_version VARCHAR(50);

COMMENT ON COLUMN ap_invoices.ai_context_summary IS 'AI-generated invoice summary: items/services purchased, business purpose';
COMMENT ON COLUMN ap_invoices.ai_context_keywords IS 'Searchable keywords from invoice description';
COMMENT ON COLUMN ap_invoices.ai_context_entities IS 'Purchase category, urgency, project association';
COMMENT ON COLUMN ap_invoices.ai_context_relationships IS 'Related vendor history, typical expense accounts, payment priority';

-- AR Invoices
ALTER TABLE ar_invoices ADD COLUMN IF NOT EXISTS ai_context_summary TEXT;
ALTER TABLE ar_invoices ADD COLUMN IF NOT EXISTS ai_context_keywords TEXT[];
ALTER TABLE ar_invoices ADD COLUMN IF NOT EXISTS ai_context_entities JSONB;
ALTER TABLE ar_invoices ADD COLUMN IF NOT EXISTS ai_context_relationships JSONB;
ALTER TABLE ar_invoices ADD COLUMN IF NOT EXISTS ai_context_generated_at TIMESTAMPTZ;
ALTER TABLE ar_invoices ADD COLUMN IF NOT EXISTS ai_context_model_version VARCHAR(50);

COMMENT ON COLUMN ar_invoices.ai_context_summary IS 'AI-generated invoice summary: products/services sold, customer context';
COMMENT ON COLUMN ar_invoices.ai_context_keywords IS 'Searchable keywords from invoice description';
COMMENT ON COLUMN ar_invoices.ai_context_entities IS 'Sale category, customer segment, revenue type';
COMMENT ON COLUMN ar_invoices.ai_context_relationships IS 'Related customer history, typical revenue accounts, collection priority';

-- ============================================
-- INDEXES FOR FAST CONTEXT SEARCH
-- ============================================

-- GIN indexes for array search on keywords
CREATE INDEX IF NOT EXISTS idx_coa_context_keywords ON chart_of_accounts USING GIN (ai_context_keywords);
CREATE INDEX IF NOT EXISTS idx_vendors_context_keywords ON vendors USING GIN (ai_context_keywords);
CREATE INDEX IF NOT EXISTS idx_customers_context_keywords ON customers USING GIN (ai_context_keywords);
CREATE INDEX IF NOT EXISTS idx_je_context_keywords ON journal_entries USING GIN (ai_context_keywords);
CREATE INDEX IF NOT EXISTS idx_ap_context_keywords ON ap_invoices USING GIN (ai_context_keywords);
CREATE INDEX IF NOT EXISTS idx_ar_context_keywords ON ar_invoices USING GIN (ai_context_keywords);

-- GIN indexes for JSONB search on entities
CREATE INDEX IF NOT EXISTS idx_coa_context_entities ON chart_of_accounts USING GIN (ai_context_entities);
CREATE INDEX IF NOT EXISTS idx_vendors_context_entities ON vendors USING GIN (ai_context_entities);
CREATE INDEX IF NOT EXISTS idx_customers_context_entities ON customers USING GIN (ai_context_entities);
CREATE INDEX IF NOT EXISTS idx_je_context_entities ON journal_entries USING GIN (ai_context_entities);
CREATE INDEX IF NOT EXISTS idx_ap_context_entities ON ap_invoices USING GIN (ai_context_entities);
CREATE INDEX IF NOT EXISTS idx_ar_context_entities ON ar_invoices USING GIN (ai_context_entities);

-- Full-text search indexes on summary
CREATE INDEX IF NOT EXISTS idx_coa_context_summary_fts ON chart_of_accounts USING GIN (to_tsvector('english', COALESCE(ai_context_summary, '')));
CREATE INDEX IF NOT EXISTS idx_vendors_context_summary_fts ON vendors USING GIN (to_tsvector('english', COALESCE(ai_context_summary, '')));
CREATE INDEX IF NOT EXISTS idx_customers_context_summary_fts ON customers USING GIN (to_tsvector('english', COALESCE(ai_context_summary, '')));
CREATE INDEX IF NOT EXISTS idx_je_context_summary_fts ON journal_entries USING GIN (to_tsvector('english', COALESCE(ai_context_summary, '')));
CREATE INDEX IF NOT EXISTS idx_ap_context_summary_fts ON ap_invoices USING GIN (to_tsvector('english', COALESCE(ai_context_summary, '')));
CREATE INDEX IF NOT EXISTS idx_ar_context_summary_fts ON ar_invoices USING GIN (to_tsvector('english', COALESCE(ai_context_summary, '')));

-- ============================================
-- HELPER FUNCTIONS FOR SEMANTIC SEARCH
-- ============================================

-- Function: Search vendors by context keywords
CREATE OR REPLACE FUNCTION search_vendors_by_context(
    p_tenant_id UUID,
    p_search_terms TEXT[]
)
RETURNS TABLE (
    vendor_id UUID,
    vendor_code VARCHAR,
    vendor_name VARCHAR,
    ai_context_summary TEXT,
    relevance_score FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        v.vendor_id,
        v.vendor_code,
        v.vendor_name,
        v.ai_context_summary,
        -- Calculate relevance score based on keyword overlap
        (
            SELECT COUNT(*)::FLOAT
            FROM unnest(v.ai_context_keywords) AS kw
            WHERE kw = ANY(p_search_terms)
        ) / GREATEST(array_length(p_search_terms, 1), 1)::FLOAT AS relevance_score
    FROM vendors v
    WHERE v.tenant_id = p_tenant_id
      AND v.ai_context_keywords && p_search_terms -- Array overlap operator
    ORDER BY relevance_score DESC, v.vendor_name;
END;
$$ LANGUAGE plpgsql;

-- Function: Search accounts by context
CREATE OR REPLACE FUNCTION search_accounts_by_context(
    p_tenant_id UUID,
    p_search_terms TEXT[]
)
RETURNS TABLE (
    account_id UUID,
    account_code VARCHAR,
    account_name VARCHAR,
    ai_context_summary TEXT,
    relevance_score FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        coa.account_id,
        coa.account_code,
        coa.account_name,
        coa.ai_context_summary,
        (
            SELECT COUNT(*)::FLOAT
            FROM unnest(coa.ai_context_keywords) AS kw
            WHERE kw = ANY(p_search_terms)
        ) / GREATEST(array_length(p_search_terms, 1), 1)::FLOAT AS relevance_score
    FROM chart_of_accounts coa
    WHERE coa.tenant_id = p_tenant_id
      AND coa.ai_context_keywords && p_search_terms
    ORDER BY relevance_score DESC, coa.account_code;
END;
$$ LANGUAGE plpgsql;

-- Function: Search transactions by context (full-text search)
CREATE OR REPLACE FUNCTION search_transactions_by_context(
    p_tenant_id UUID,
    p_search_query TEXT
)
RETURNS TABLE (
    entry_id UUID,
    entry_number VARCHAR,
    entry_date DATE,
    description TEXT,
    ai_context_summary TEXT,
    relevance_score FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        je.entry_id,
        je.entry_number,
        je.entry_date,
        je.description,
        je.ai_context_summary,
        ts_rank(
            to_tsvector('english', COALESCE(je.ai_context_summary, '')),
            plainto_tsquery('english', p_search_query)
        ) AS relevance_score
    FROM journal_entries je
    WHERE je.tenant_id = p_tenant_id
      AND to_tsvector('english', COALESCE(je.ai_context_summary, '')) @@ plainto_tsquery('english', p_search_query)
    ORDER BY relevance_score DESC, je.entry_date DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- CONTEXT COVERAGE VIEW
-- ============================================

CREATE OR REPLACE VIEW ai_context_coverage AS
SELECT
    'chart_of_accounts' AS table_name,
    COUNT(*) AS total_records,
    COUNT(ai_context_summary) AS records_with_context,
    ROUND(100.0 * COUNT(ai_context_summary) / NULLIF(COUNT(*), 0), 2) AS coverage_percentage,
    MAX(ai_context_generated_at) AS last_generated
FROM chart_of_accounts
UNION ALL
SELECT
    'vendors',
    COUNT(*),
    COUNT(ai_context_summary),
    ROUND(100.0 * COUNT(ai_context_summary) / NULLIF(COUNT(*), 0), 2),
    MAX(ai_context_generated_at)
FROM vendors
UNION ALL
SELECT
    'customers',
    COUNT(*),
    COUNT(ai_context_summary),
    ROUND(100.0 * COUNT(ai_context_summary) / NULLIF(COUNT(*), 0), 2),
    MAX(ai_context_generated_at)
FROM customers
UNION ALL
SELECT
    'journal_entries',
    COUNT(*),
    COUNT(ai_context_summary),
    ROUND(100.0 * COUNT(ai_context_summary) / NULLIF(COUNT(*), 0), 2),
    MAX(ai_context_generated_at)
FROM journal_entries
UNION ALL
SELECT
    'ap_invoices',
    COUNT(*),
    COUNT(ai_context_summary),
    ROUND(100.0 * COUNT(ai_context_summary) / NULLIF(COUNT(*), 0), 2),
    MAX(ai_context_generated_at)
FROM ap_invoices
UNION ALL
SELECT
    'ar_invoices',
    COUNT(*),
    COUNT(ai_context_summary),
    ROUND(100.0 * COUNT(ai_context_summary) / NULLIF(COUNT(*), 0), 2),
    MAX(ai_context_generated_at)
FROM ar_invoices;

-- ============================================
-- MIGRATION COMPLETE
-- ============================================

-- Log migration success
DO $$
BEGIN
    RAISE NOTICE '✅ AI Context Metadata Migration Complete';
    RAISE NOTICE '   - Added context fields to 6 tables';
    RAISE NOTICE '   - Created 18 indexes for fast semantic search';
    RAISE NOTICE '   - Created 3 helper functions for context search';
    RAISE NOTICE '   - Created coverage view for monitoring';
    RAISE NOTICE '   Next: Run AI Context Generator to populate context data';
END $$;
