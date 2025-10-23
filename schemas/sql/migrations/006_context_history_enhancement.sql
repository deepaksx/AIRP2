-- ============================================
-- AIRP v2.13.1 - AI Context History Enhancement
-- Change from overwrite to incremental append
-- ============================================

-- Add context history array column to all master data tables
-- Stores last 10 snapshots of context evolution

ALTER TABLE users ADD COLUMN IF NOT EXISTS ai_context_history JSONB[] DEFAULT '{}';
ALTER TABLE vendors ADD COLUMN IF NOT EXISTS ai_context_history JSONB[] DEFAULT '{}';
ALTER TABLE customers ADD COLUMN IF NOT EXISTS ai_context_history JSONB[] DEFAULT '{}';
ALTER TABLE chart_of_accounts ADD COLUMN IF NOT EXISTS ai_context_history JSONB[] DEFAULT '{}';

-- Add index for array operations
CREATE INDEX IF NOT EXISTS idx_users_context_history ON users USING GIN(ai_context_history);
CREATE INDEX IF NOT EXISTS idx_vendors_context_history ON vendors USING GIN(ai_context_history);
CREATE INDEX IF NOT EXISTS idx_customers_context_history ON customers USING GIN(ai_context_history);
CREATE INDEX IF NOT EXISTS idx_coa_context_history ON chart_of_accounts USING GIN(ai_context_history);

-- Create helper function to merge keywords intelligently
-- Keeps unique keywords, prioritizes recent ones, limits to 100
CREATE OR REPLACE FUNCTION merge_context_keywords(
    existing_keywords TEXT[],
    new_keywords TEXT[],
    max_keywords INTEGER DEFAULT 100
)
RETURNS TEXT[] AS $$
DECLARE
    merged_keywords TEXT[];
BEGIN
    -- Combine arrays, get distinct values, limit to max
    SELECT array_agg(DISTINCT keyword ORDER BY keyword)
    INTO merged_keywords
    FROM (
        -- New keywords first (higher priority)
        SELECT unnest(COALESCE(new_keywords, ARRAY[]::TEXT[])) as keyword
        UNION
        -- Then existing keywords
        SELECT unnest(COALESCE(existing_keywords, ARRAY[]::TEXT[])) as keyword
    ) combined
    LIMIT max_keywords;

    RETURN COALESCE(merged_keywords, ARRAY[]::TEXT[]);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create helper function to append context history
-- Keeps last N snapshots
CREATE OR REPLACE FUNCTION append_context_history(
    current_history JSONB[],
    current_summary TEXT,
    current_keywords TEXT[],
    current_entities JSONB,
    current_relationships JSONB,
    current_generated_at TIMESTAMPTZ,
    current_model_version VARCHAR,
    max_history INTEGER DEFAULT 10
)
RETURNS JSONB[] AS $$
DECLARE
    new_snapshot JSONB;
    updated_history JSONB[];
BEGIN
    -- Don't append if current context is null
    IF current_summary IS NULL THEN
        RETURN current_history;
    END IF;

    -- Build snapshot
    new_snapshot := jsonb_build_object(
        'summary', current_summary,
        'keywords', current_keywords,
        'entities', current_entities,
        'relationships', current_relationships,
        'generated_at', current_generated_at,
        'model_version', current_model_version
    );

    -- Append to history, keeping only last N-1 items
    -- (since we're about to add new current context)
    IF array_length(current_history, 1) >= max_history THEN
        -- Keep last (max_history - 1) items
        updated_history := current_history[2:max_history] || new_snapshot;
    ELSE
        -- Just append
        updated_history := COALESCE(current_history, ARRAY[]::JSONB[]) || new_snapshot;
    END IF;

    RETURN updated_history;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create view to analyze context evolution
CREATE OR REPLACE VIEW vw_context_evolution AS
SELECT
    'user' as entity_type,
    user_id as entity_id,
    username as entity_name,
    ai_context_summary as current_summary,
    array_length(ai_context_keywords, 1) as keyword_count,
    array_length(ai_context_history, 1) as history_count,
    ai_context_generated_at as last_updated,
    ai_context_model_version as model_version,
    (ai_context_history[array_length(ai_context_history, 1)]->>'generated_at')::timestamptz as previous_update,
    CASE
        WHEN ai_context_generated_at IS NULL THEN 'never_generated'
        WHEN ai_context_generated_at < NOW() - INTERVAL '30 days' THEN 'stale'
        WHEN array_length(ai_context_history, 1) = 0 THEN 'new'
        ELSE 'current'
    END as context_status
FROM users
WHERE status = 'active'

UNION ALL

SELECT
    'vendor' as entity_type,
    vendor_id as entity_id,
    vendor_name as entity_name,
    ai_context_summary,
    array_length(ai_context_keywords, 1),
    array_length(ai_context_history, 1),
    ai_context_generated_at,
    ai_context_model_version,
    (ai_context_history[array_length(ai_context_history, 1)]->>'generated_at')::timestamptz,
    CASE
        WHEN ai_context_generated_at IS NULL THEN 'never_generated'
        WHEN ai_context_generated_at < NOW() - INTERVAL '30 days' THEN 'stale'
        WHEN array_length(ai_context_history, 1) = 0 THEN 'new'
        ELSE 'current'
    END
FROM vendors
WHERE status = 'active'

UNION ALL

SELECT
    'customer' as entity_type,
    customer_id as entity_id,
    customer_name as entity_name,
    ai_context_summary,
    array_length(ai_context_keywords, 1),
    array_length(ai_context_history, 1),
    ai_context_generated_at,
    ai_context_model_version,
    (ai_context_history[array_length(ai_context_history, 1)]->>'generated_at')::timestamptz,
    CASE
        WHEN ai_context_generated_at IS NULL THEN 'never_generated'
        WHEN ai_context_generated_at < NOW() - INTERVAL '90 days' THEN 'stale'
        WHEN array_length(ai_context_history, 1) = 0 THEN 'new'
        ELSE 'current'
    END
FROM customers
WHERE status = 'active'

UNION ALL

SELECT
    'chart_of_account' as entity_type,
    account_id as entity_id,
    account_code || ' - ' || account_name as entity_name,
    ai_context_summary,
    array_length(ai_context_keywords, 1),
    array_length(ai_context_history, 1),
    ai_context_generated_at,
    ai_context_model_version,
    (ai_context_history[array_length(ai_context_history, 1)]->>'generated_at')::timestamptz,
    CASE
        WHEN ai_context_generated_at IS NULL THEN 'never_generated'
        WHEN ai_context_generated_at < NOW() - INTERVAL '90 days' THEN 'stale'
        WHEN array_length(ai_context_history, 1) = 0 THEN 'new'
        ELSE 'current'
    END
FROM chart_of_accounts
WHERE status = 'active';

-- Create function to get context history for an entity
CREATE OR REPLACE FUNCTION get_context_history(
    p_entity_type TEXT,
    p_entity_id UUID
)
RETURNS TABLE(
    snapshot_index INTEGER,
    summary TEXT,
    keywords TEXT[],
    entities JSONB,
    relationships JSONB,
    generated_at TIMESTAMPTZ,
    model_version TEXT
) AS $$
BEGIN
    IF p_entity_type = 'user' THEN
        RETURN QUERY
        SELECT
            idx,
            snapshot->>'summary',
            ARRAY(SELECT jsonb_array_elements_text(snapshot->'keywords')),
            snapshot->'entities',
            snapshot->'relationships',
            (snapshot->>'generated_at')::timestamptz,
            snapshot->>'model_version'
        FROM users,
             unnest(ai_context_history) WITH ORDINALITY AS t(snapshot, idx)
        WHERE user_id = p_entity_id
        ORDER BY idx DESC;

    ELSIF p_entity_type = 'vendor' THEN
        RETURN QUERY
        SELECT
            idx,
            snapshot->>'summary',
            ARRAY(SELECT jsonb_array_elements_text(snapshot->'keywords')),
            snapshot->'entities',
            snapshot->'relationships',
            (snapshot->>'generated_at')::timestamptz,
            snapshot->>'model_version'
        FROM vendors,
             unnest(ai_context_history) WITH ORDINALITY AS t(snapshot, idx)
        WHERE vendor_id = p_entity_id
        ORDER BY idx DESC;

    ELSIF p_entity_type = 'customer' THEN
        RETURN QUERY
        SELECT
            idx,
            snapshot->>'summary',
            ARRAY(SELECT jsonb_array_elements_text(snapshot->'keywords')),
            snapshot->'entities',
            snapshot->'relationships',
            (snapshot->>'generated_at')::timestamptz,
            snapshot->>'model_version'
        FROM customers,
             unnest(ai_context_history) WITH ORDINALITY AS t(snapshot, idx)
        WHERE customer_id = p_entity_id
        ORDER BY idx DESC;

    ELSIF p_entity_type = 'chart_of_account' THEN
        RETURN QUERY
        SELECT
            idx,
            snapshot->>'summary',
            ARRAY(SELECT jsonb_array_elements_text(snapshot->'keywords')),
            snapshot->'entities',
            snapshot->'relationships',
            (snapshot->>'generated_at')::timestamptz,
            snapshot->>'model_version'
        FROM chart_of_accounts,
             unnest(ai_context_history) WITH ORDINALITY AS t(snapshot, idx)
        WHERE account_id = p_entity_id
        ORDER BY idx DESC;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Add comments
COMMENT ON COLUMN users.ai_context_history IS 'Last 10 snapshots of AI-generated context for tracking evolution';
COMMENT ON COLUMN vendors.ai_context_history IS 'Last 10 snapshots of AI-generated context for tracking evolution';
COMMENT ON COLUMN customers.ai_context_history IS 'Last 10 snapshots of AI-generated context for tracking evolution';
COMMENT ON COLUMN chart_of_accounts.ai_context_history IS 'Last 10 snapshots of AI-generated context for tracking evolution';

COMMENT ON FUNCTION merge_context_keywords IS 'Intelligently merges new and existing keywords, keeping most relevant';
COMMENT ON FUNCTION append_context_history IS 'Appends current context to history array, maintaining max N snapshots';
COMMENT ON FUNCTION get_context_history IS 'Retrieves context evolution history for any entity';
COMMENT ON VIEW vw_context_evolution IS 'Overview of context status and evolution for all entities';

-- Example usage queries
/*
-- View context evolution status
SELECT * FROM vw_context_evolution ORDER BY last_updated DESC;

-- Get history for a specific user
SELECT * FROM get_context_history('user', '00000000-0000-0000-0000-000000000001');

-- Find entities with stale context
SELECT * FROM vw_context_evolution WHERE context_status = 'stale';

-- Find entities never generated
SELECT * FROM vw_context_evolution WHERE context_status = 'never_generated';
*/
