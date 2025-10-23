# AI Context History Enhancement - AIRP v2.13.1

## Overview

Enhancement to the AI context system that changes from **overwriting** context to **incremental append with history tracking**. This provides full audit trail of context evolution, better search through accumulated keywords, and trend analysis capabilities.

## Problem Statement

**Previous Behavior (v2.13.0):**
- Context was completely overwritten on each update
- Historical context was lost
- Keywords could disappear if no longer relevant
- No ability to track how entity context evolved over time
- No trend analysis possible

**New Behavior (v2.13.1):**
- Context is **appended** with keyword merging
- Last 10 historical snapshots retained
- Keywords accumulate (up to 100 unique)
- Full evolution timeline available
- Trend analysis and growth metrics

## Key Changes

### 1. Database Schema Enhancement

**New Column Added to All Master Data Tables:**
```sql
ALTER TABLE users ADD COLUMN ai_context_history JSONB[];
ALTER TABLE vendors ADD COLUMN ai_context_history JSONB[];
ALTER TABLE customers ADD COLUMN ai_context_history JSONB[];
ALTER TABLE chart_of_accounts ADD COLUMN ai_context_history JSONB[];
```

**History Structure:**
```json
[
  {
    "summary": "User primarily works with AP invoices...",
    "keywords": ["accounting", "ap", "invoices", "vendor_management"],
    "entities": {...},
    "relationships": {...},
    "generated_at": "2025-10-15T10:30:00Z",
    "model_version": "claude-3.5-sonnet"
  },
  // ... up to 9 more snapshots
]
```

### 2. Smart Keyword Merging

**PostgreSQL Function:**
```sql
CREATE FUNCTION merge_context_keywords(
    existing_keywords TEXT[],
    new_keywords TEXT[],
    max_keywords INTEGER DEFAULT 100
) RETURNS TEXT[]
```

**Behavior:**
- Combines existing + new keywords
- Removes duplicates
- Prioritizes new keywords (appear first)
- Limits to 100 total (configurable)
- Automatically called during context updates

**Example:**
```sql
-- Existing: ['accounting', 'finance', 'reports']
-- New: ['accounting', 'compliance', 'audit']
-- Result: ['accounting', 'compliance', 'audit', 'finance', 'reports']
-- (5 total, no duplicates, new keywords prioritized)
```

### 3. History Append Function

**PostgreSQL Function:**
```sql
CREATE FUNCTION append_context_history(
    current_history JSONB[],
    current_summary TEXT,
    current_keywords TEXT[],
    current_entities JSONB,
    current_relationships JSONB,
    current_generated_at TIMESTAMPTZ,
    current_model_version VARCHAR,
    max_history INTEGER DEFAULT 10
) RETURNS JSONB[]
```

**Behavior:**
- Takes current context snapshot before update
- Appends to history array
- Keeps only last N snapshots (default 10)
- Automatically removes oldest when limit reached
- FIFO (First In, First Out) retention

### 4. Context Update Strategy

**Before (Overwrite):**
```sql
UPDATE users
SET
  ai_context_summary = $1,          -- Replaces completely
  ai_context_keywords = $2,          -- Replaces array
  ai_context_entities = $3,          -- Replaces JSONB
  ai_context_generated_at = NOW()
WHERE user_id = $6
```

**After (Incremental):**
```sql
UPDATE users
SET
  -- Save current state to history
  ai_context_history = append_context_history(
    ai_context_history,
    ai_context_summary,
    ai_context_keywords,
    ai_context_entities,
    ai_context_relationships,
    ai_context_generated_at,
    ai_context_model_version,
    10  -- Keep last 10 snapshots
  ),
  -- Update current context
  ai_context_summary = $1,                                    -- New summary
  ai_context_keywords = merge_context_keywords(              -- Merged keywords
    ai_context_keywords,
    $2,
    100  -- Max 100 keywords
  ),
  ai_context_entities = $3,                                   -- Latest entities
  ai_context_relationships = $4,                              -- Latest relationships
  ai_context_generated_at = NOW(),
  ai_context_model_version = $5
WHERE user_id = $6
```

## API Endpoints

### Get Context History

**Endpoint:**
`GET /users/:id/context-history`

**Description:**
Returns all historical context snapshots for a user (or any entity)

**Response:**
```json
[
  {
    "snapshotIndex": 10,
    "summary": "Current summary...",
    "keywords": ["current", "keywords"],
    "entities": {...},
    "relationships": {...},
    "generatedAt": "2025-10-23T15:30:00Z",
    "modelVersion": "claude-3.5-sonnet"
  },
  {
    "snapshotIndex": 9,
    "summary": "Previous summary...",
    "keywords": ["older", "keywords"],
    "generatedAt": "2025-10-20T10:15:00Z",
    "modelVersion": "claude-3.5-sonnet"
  }
  // ... up to 8 more snapshots
]
```

### Get Context Evolution

**Endpoint:**
`GET /users/:id/context-evolution`

**Description:**
Returns comprehensive evolution analysis with keyword trends and growth metrics

**Response:**
```json
{
  "user_id": "uuid",
  "username": "john.doe",
  "full_name": "John Doe",
  "current_context": {
    "summary": "Accountant focused on AP operations...",
    "keywords": ["accounting", "ap", "invoices", "vendor_management", "finance"],
    "keyword_count": 45,
    "generated_at": "2025-10-23T15:30:00Z",
    "model_version": "claude-3.5-sonnet"
  },
  "history_count": 8,
  "history": [ /* array of snapshots */ ],
  "keyword_evolution": {
    "total_unique_keywords": 45,
    "new_keywords": ["compliance", "audit", "sox"],  // Added since oldest snapshot
    "persistent_keywords": ["accounting", "ap", "invoices"],  // Present in all snapshots
    "removed_keywords": ["training", "onboarding"],  // Were in oldest, no longer present
    "growth_rate": "28.6%"  // Percentage increase from oldest snapshot
  }
}
```

## UI Enhancement

### Context Evolution Timeline

**New Button in User Management:**
- 📊 icon button on each user card
- Opens modal with timeline visualization

**Timeline Features:**
- **Summary Stats:**
  - Total snapshots
  - Current keyword count
  - New keywords added
  - Persistent keywords
  - Growth rate percentage

- **Visual Timeline:**
  - Current context highlighted (green dot)
  - Historical snapshots with timestamps
  - Keyword tags with visual indicators:
    - **Green background:** New keywords
    - **Gray background:** Existing keywords
    - **Red background with strikethrough:** Removed keywords

- **Interactive:**
  - Click to view full snapshot details
  - Scroll through history chronologically
  - Compare keywords across snapshots

## Database Views

### Context Evolution View

**View Name:** `vw_context_evolution`

**Purpose:**
System-wide overview of context status for all entities

**Columns:**
- `entity_type` - user, vendor, customer, chart_of_account
- `entity_id` - UUID
- `entity_name` - Display name
- `current_summary` - Latest AI summary
- `keyword_count` - Number of current keywords
- `history_count` - Number of historical snapshots
- `last_updated` - When context was last generated
- `model_version` - AI model used
- `previous_update` - Timestamp of previous snapshot
- `context_status` - never_generated, new, current, stale

**Query Examples:**
```sql
-- View all entities needing context update
SELECT * FROM vw_context_evolution
WHERE context_status = 'stale'
ORDER BY last_updated ASC;

-- Count entities by status
SELECT context_status, COUNT(*)
FROM vw_context_evolution
GROUP BY context_status;

-- Find top growing contexts
SELECT entity_name, keyword_count, history_count
FROM vw_context_evolution
WHERE history_count >= 5
ORDER BY keyword_count DESC
LIMIT 20;
```

### Helper Function

**Function:** `get_context_history(entity_type, entity_id)`

**Purpose:**
Retrieve formatted context history for any entity type

**Usage:**
```sql
-- Get user context history
SELECT * FROM get_context_history('user', '00000000-0000-0000-0000-000000000001');

-- Get vendor context history
SELECT * FROM get_context_history('vendor', 'vendor-uuid-here');

-- Get customer context history
SELECT * FROM get_context_history('customer', 'customer-uuid-here');

-- Get GL account context history
SELECT * FROM get_context_history('chart_of_account', 'account-uuid-here');
```

## Benefits

### 1. Audit Trail & Compliance
- **Full History:** Last 10 snapshots retained for audit
- **Timestamps:** Exact generation time for each context
- **Model Tracking:** Know which AI version generated each context
- **SOX/IFRS Compliant:** Maintains change history for regulators

### 2. Better Search & Discovery
- **Accumulated Keywords:** Keywords build up over time (up to 100)
- **Historical Relevance:** Old but relevant keywords preserved
- **Multi-Dimensional:** Search across current + historical context
- **Trend-Based:** Find entities with growing/shrinking keyword sets

### 3. Trend Analysis
- **Growth Metrics:** Track keyword growth rate over time
- **Pattern Recognition:** Identify changing user behavior
- **Role Evolution:** See how user roles/responsibilities evolve
- **Vendor/Customer Changes:** Track relationship changes

### 4. Context Quality
- **No Data Loss:** Historical context never deleted
- **Smart Merging:** Relevant keywords accumulated intelligently
- **Revert Capability:** Can see what was "before" bad context generation
- **Debugging:** Understand why certain keywords appeared

### 5. Performance
- **Indexed Arrays:** GIN indexes on keyword arrays for fast search
- **Limited Growth:** Max 100 keywords, max 10 snapshots prevents bloat
- **Parallel Updates:** Context updates still run in parallel per entity type
- **Non-Blocking:** Failures don't affect main operations

## Configuration

### Maximum Keywords

**Default:** 100
**Location:** Database function `merge_context_keywords`

**To Change:**
```sql
-- Update function default
CREATE OR REPLACE FUNCTION merge_context_keywords(
    existing_keywords TEXT[],
    new_keywords TEXT[],
    max_keywords INTEGER DEFAULT 150  -- Changed from 100
)
...
```

### Maximum History Snapshots

**Default:** 10
**Location:** Database function `append_context_history`

**To Change:**
```sql
-- Update function default
CREATE OR REPLACE FUNCTION append_context_history(
    ...
    max_history INTEGER DEFAULT 20  -- Changed from 10
)
...
```

## Migration Guide

### From v2.13.0 to v2.13.1

**1. Run Database Migration:**
```bash
psql -U airp_admin -d airp_master -f schemas/sql/migrations/006_context_history_enhancement.sql
```

**2. Restart User Management Service:**
```bash
cd services/user-management-service
npm run build
npm run start:prod
```

**3. Rebuild Existing Contexts (Optional):**
```sql
-- Mark all entities for context regeneration
UPDATE users SET metadata = metadata || '{"context_update_needed": true}';
UPDATE vendors SET metadata = metadata || '{"context_update_needed": true}';
UPDATE customers SET metadata = metadata || '{"context_update_needed": true}';
UPDATE chart_of_accounts SET metadata = metadata || '{"context_update_needed": true}';

-- Context worker will pick them up in next 5-minute cycle
```

**4. Verify:**
```sql
-- Check history is being populated
SELECT
  username,
  array_length(ai_context_keywords, 1) as keyword_count,
  array_length(ai_context_history, 1) as history_count
FROM users
WHERE ai_context_history IS NOT NULL
LIMIT 5;
```

## Monitoring

### Health Checks

**Check context generation progress:**
```sql
SELECT * FROM vw_context_evolution;
```

**Find entities with most history:**
```sql
SELECT entity_name, history_count, keyword_count
FROM vw_context_evolution
ORDER BY history_count DESC
LIMIT 10;
```

**Track keyword growth:**
```sql
SELECT
  u.username,
  array_length(u.ai_context_keywords, 1) as current_keywords,
  array_length((u.ai_context_history[1]->'keywords')::text[], 1) as oldest_keywords,
  array_length(u.ai_context_keywords, 1) -
    COALESCE(array_length((u.ai_context_history[1]->'keywords')::text[], 1), 0) as growth
FROM users u
WHERE ai_context_history IS NOT NULL
  AND array_length(ai_context_history, 1) > 0
ORDER BY growth DESC;
```

## Example Scenarios

### Scenario 1: User Role Change

**Initial State (Accountant):**
```json
{
  "summary": "Accountant focused on AP invoice processing",
  "keywords": ["accounting", "ap", "invoices", "vendor_management"]
}
```

**After Promotion to Controller:**
```json
{
  "summary": "Controller overseeing accounting operations and reporting",
  "keywords": [
    "accounting", "ap", "invoices", "vendor_management",  // Preserved
    "controller", "financial_reporting", "oversight", "compliance"  // Added
  ]
}
```

**History Preserved:**
- Old summary still in history
- Original keywords retained
- Can see role evolution over time

### Scenario 2: Vendor Relationship Growth

**Initial (Small Vendor):**
```json
{
  "keywords": ["office_supplies", "small_vendor", "monthly_orders"]
}
```

**After 6 Months (Major Vendor):**
```json
{
  "keywords": [
    "office_supplies", "small_vendor", "monthly_orders",  // Original preserved
    "strategic_vendor", "volume_pricing", "weekly_deliveries",
    "preferred_supplier", "contract_negotiation"  // Business growth
  ]
}
```

### Scenario 3: Seasonal Business Patterns

**Q1 Context:**
```json
{
  "keywords": ["tax_prep", "year_end_close", "audit_support"]
}
```

**Q2 Context (Accumulated):**
```json
{
  "keywords": [
    "tax_prep", "year_end_close", "audit_support",  // Q1 preserved
    "budgeting", "forecasting", "planning"  // Q2 added
  ]
}
```

## Future Enhancements

1. **Context Diff Viewer:** Visual comparison between snapshots
2. **Keyword Heatmap:** Visualize keyword frequency over time
3. **Automatic Insights:** AI-generated insights on context changes
4. **Export Timeline:** Export context evolution to PDF/CSV
5. **Custom Retention:** Per-tenant configuration of history limits
6. **Context Rollback:** Ability to revert to previous context snapshot

## Files Modified

### Database
- `schemas/sql/migrations/006_context_history_enhancement.sql` - New migration

### Backend
- `services/user-management-service/src/workers/context-updater.service.ts` - Updated all 4 entity updates
- `services/user-management-service/src/users/users.controller.ts` - Added 2 new endpoints
- `services/user-management-service/src/users/users.service.ts` - Added history retrieval methods

### Frontend
- `user-management.html` - Added timeline modal and visualization

### Documentation
- `docs/CONTEXT_HISTORY_ENHANCEMENT.md` - This file

## Version History

- **v2.13.1** (October 2025): Context history enhancement
  - Incremental keyword merging
  - Historical snapshots (last 10)
  - Evolution timeline UI
  - Trend analysis
  - PostgreSQL helper functions

---

**Migration File:** `schemas/sql/migrations/006_context_history_enhancement.sql`
**Status:** Production-ready
**Breaking Changes:** None (backward compatible)
