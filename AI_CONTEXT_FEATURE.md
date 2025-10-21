# AIRP v2.11.0 - AI Context-Aware Natural Language Querying

## **Overview**

The AI Context feature transforms ChatERP from a basic query interface into an intelligent financial assistant that truly understands your business. Every vendor, customer, account, and transaction now has AI-generated contextual metadata that enables semantic search and natural language understanding.

## **What's New**

### **Intelligent Context Metadata**

Every record in your ERP now has:
- **AI Context Summary**: Plain English description of the record's business purpose
- **Searchable Keywords**: Extracted terms users might search for
- **Business Entities**: Structured classification and patterns
- **Relationships**: Connections to other records and typical usage patterns

### **Semantic Search**

Find records by business meaning, not just field values:
- "Who sells office supplies?" → Finds vendors with relevant keywords
- "Which account for rent?" → Suggests appropriate GL accounts
- "Find IT equipment vendors" → Semantic matching across vendor records

### **Context-Enriched Responses**

ChatERP now provides rich, contextual answers:
- Business summaries alongside data
- Typical usage patterns and relationships
- Smart suggestions based on historical context

---

## **Architecture**

```
┌─────────────────────────────────────────┐
│  User: "Who sells office supplies?"     │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│  ChatERP Frontend (Port 5000)           │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│  AI Query Parser (Port 8006)            │
│  - Parse natural language               │
│  - Generate semantic SQL query          │
│  - Search ai_context_keywords           │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│  PostgreSQL with AI Context Indexes     │
│  - GIN indexes on keyword arrays        │
│  - JSONB indexes on entities            │
│  - Full-text search on summaries        │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│  AI Response Formatter (Port 8006)      │
│  - Include context in results           │
│  - Format as rich HTML                  │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│  Context-Enriched Response Displayed    │
└─────────────────────────────────────────┘
```

---

## **Database Schema**

### **New Columns (Added to All Tables)**

```sql
-- AI-Generated Context Fields
ai_context_summary TEXT,              -- Plain English description
ai_context_keywords TEXT[],            -- Searchable keyword array
ai_context_entities JSONB,             -- Structured business entities
ai_context_relationships JSONB,        -- Related records and patterns
ai_context_generated_at TIMESTAMPTZ,   -- Generation timestamp
ai_context_model_version VARCHAR(50)   -- AI model version used
```

### **Indexed for Fast Search**

- **GIN Indexes** on `ai_context_keywords` arrays
- **GIN Indexes** on `ai_context_entities` JSONB
- **Full-Text Search** indexes on `ai_context_summary`

### **Tables Enhanced**

1. `chart_of_accounts` - Account purpose and usage
2. `vendors` - Vendor classification and products/services
3. `customers` - Customer profiles and buying patterns
4. `journal_entries` - Transaction business purpose
5. `ap_invoices` - Invoice context and categorization
6. `ar_invoices` - Revenue context and customer patterns

---

## **AI Context Generator Service (Port 8007)**

### **Endpoints**

#### **POST /generate-context**
Generate context for a single entity.

```bash
curl -X POST http://localhost:8007/generate-context \
  -H "Content-Type: application/json" \
  -d '{
    "entity_type": "vendor",
    "entity_id": "uuid-here",
    "tenant_id": "00000000-0000-0000-0000-000000000001",
    "entity_data": {
      "vendor_name": "Emirates Office Supplies LLC",
      "payment_terms": 30
    }
  }'
```

**Response:**
```json
{
  "entity_type": "vendor",
  "entity_id": "uuid",
  "ai_context_summary": "Emirates Office Supplies LLC is a Dubai-based vendor providing office stationery, supplies, and equipment with 30-day payment terms.",
  "ai_context_keywords": ["office", "supplies", "stationery", "Dubai", "equipment"],
  "ai_context_entities": {
    "vendor_type": "supplier",
    "industry": "office supplies",
    "payment_behavior": "net_30"
  },
  "ai_context_relationships": {
    "typical_gl_accounts": ["5500"],
    "estimated_monthly_spend": "medium"
  }
}
```

#### **POST /batch-generate**
Generate context for multiple records.

```bash
curl -X POST http://localhost:8007/batch-generate \
  -H "Content-Type: application/json" \
  -d '{
    "entity_type": "vendor",
    "tenant_id": "00000000-0000-0000-0000-000000000001",
    "limit": 100
  }'
```

**Response:**
```json
{
  "entity_type": "vendor",
  "total_processed": 25,
  "successful": 25,
  "failed": 0,
  "coverage_percentage": 100.0
}
```

#### **GET /context-stats**
Get context coverage statistics.

```bash
curl "http://localhost:8007/context-stats?tenant_id=00000000-0000-0000-0000-000000000001"
```

**Response:**
```json
{
  "total_records": 150,
  "records_with_context": 142,
  "coverage_percentage": 94.67,
  "by_entity_type": {
    "chart_of_accounts": {
      "total_records": 51,
      "records_with_context": 51,
      "coverage_percentage": 100.0
    },
    "vendors": {
      "total_records": 25,
      "records_with_context": 25,
      "coverage_percentage": 100.0
    }
  }
}
```

---

## **Semantic Search Examples**

### **1. Keyword Array Search (Fast)**

```sql
-- Find vendors selling office supplies
SELECT vendor_id, vendor_name, ai_context_summary
FROM vendors
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  AND ai_context_keywords && ARRAY['office', 'supplies', 'stationery']
ORDER BY vendor_name;
```

### **2. Full-Text Search (More Powerful)**

```sql
-- Find vendors with "IT" in their context
SELECT vendor_id, vendor_name, ai_context_summary,
       ts_rank(to_tsvector('english', ai_context_summary),
               plainto_tsquery('english', 'IT equipment')) AS relevance
FROM vendors
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  AND to_tsvector('english', ai_context_summary) @@
      plainto_tsquery('english', 'IT equipment')
ORDER BY relevance DESC;
```

### **3. JSONB Entity Search**

```sql
-- Find accounts with fixed monthly usage pattern
SELECT account_code, account_name, ai_context_summary
FROM chart_of_accounts
WHERE tenant_id = '00000000-0000-0000-0000-000000000001'
  AND ai_context_entities->>'usage_pattern' = 'fixed_monthly';
```

### **4. Using Helper Functions**

```sql
-- Search vendors by context keywords (uses built-in function)
SELECT * FROM search_vendors_by_context(
  '00000000-0000-0000-0000-000000000001',
  ARRAY['utilities', 'electricity']
);
```

---

## **Setup Instructions**

### **1. Run Database Migration**

```powershell
# Run the migration script
.\run_context_migration.ps1
```

Or manually:

```bash
docker exec -i airp-postgres psql -U airp_admin -d airp_master < schemas/sql/migrations/002_add_ai_context_fields.sql
```

### **2. Start AI Context Generator**

```bash
# Make sure you have ANTHROPIC_API_KEY set
docker compose up -d ai-context-generator

# Check health
curl http://localhost:8007/health
```

### **3. Generate Context for Existing Data**

```powershell
# Run the batch generation script
.\run_generate_contexts.ps1
```

Or manually:

```bash
# Generate context for vendors
curl -X POST http://localhost:8007/batch-generate \
  -H "Content-Type: application/json" \
  -d '{
    "entity_type": "vendor",
    "tenant_id": "00000000-0000-0000-0000-000000000001",
    "limit": 100
  }'

# Generate context for accounts
curl -X POST http://localhost:8007/batch-generate \
  -H "Content-Type: application/json" \
  -d '{
    "entity_type": "account",
    "tenant_id": "00000000-0000-0000-0000-000000000001",
    "limit": 100
  }'
```

### **4. Test in ChatERP**

Open http://localhost:5000/chaterp.html and try:

- "Who sells office supplies?"
- "Find vendors for IT equipment"
- "Which account should I use for rent payments?"
- "Show me utility vendors"

---

## **Context Generation Details**

### **Vendor Context Example**

**Input:**
```json
{
  "vendor_name": "Emirates Office Supplies LLC",
  "vendor_code": "V001",
  "payment_terms": 30,
  "contact_email": "billing@emiratesoffice.ae"
}
```

**Generated Context:**
```json
{
  "ai_context_summary": "Emirates Office Supplies LLC is a Dubai-based vendor providing office stationery, supplies, and equipment with 30-day payment terms. Primary supplier for day-to-day office consumables.",

  "ai_context_keywords": [
    "office supplies", "stationery", "paper", "pens",
    "folders", "Dubai", "UAE", "office equipment"
  ],

  "ai_context_entities": {
    "vendor_type": "supplier",
    "industry": "office supplies and equipment",
    "products_services": ["stationery", "office supplies", "paper products"],
    "payment_behavior": "net_30",
    "typical_expense_categories": ["office supplies", "stationery"]
  },

  "ai_context_relationships": {
    "typical_gl_accounts": ["5500"],
    "account_names": ["Office Supplies"],
    "estimated_monthly_spend": "medium",
    "transaction_frequency": "monthly"
  }
}
```

### **GL Account Context Example**

**Input:**
```json
{
  "account_code": "5300",
  "account_name": "Rent Expense",
  "account_type": "Expense",
  "normal_balance": "Debit"
}
```

**Generated Context:**
```json
{
  "ai_context_summary": "Rent Expense (5300) records monthly office or facility rental payments. Typically a fixed recurring expense posted at the beginning of each month.",

  "ai_context_keywords": [
    "rent", "lease", "office rent", "facility rent",
    "property", "monthly rent", "rental"
  ],

  "ai_context_entities": {
    "usage_pattern": "fixed_monthly",
    "typical_transaction_types": ["expense", "payment"],
    "materiality": "high",
    "financial_statement_category": "operating_expense"
  },

  "ai_context_relationships": {
    "common_vendors": [],
    "parent_account": "5000",
    "related_accounts": ["1000", "2100"]
  }
}
```

---

## **Performance Considerations**

### **Context Generation**
- **Speed**: ~2-3 seconds per record (Claude API call)
- **Batch Processing**: Recommended for existing data
- **Async Recommended**: For real-time generation on record creation

### **Search Performance**
- **Keyword Array Search**: < 10ms (GIN indexed)
- **Full-Text Search**: < 50ms (GIN indexed)
- **JSONB Search**: < 20ms (GIN indexed)

### **Indexes Created**
```sql
-- Fast array overlap search
CREATE INDEX idx_vendors_context_keywords ON vendors USING GIN (ai_context_keywords);

-- JSONB path search
CREATE INDEX idx_vendors_context_entities ON vendors USING GIN (ai_context_entities);

-- Full-text search
CREATE INDEX idx_vendors_context_summary_fts ON vendors
  USING GIN (to_tsvector('english', COALESCE(ai_context_summary, '')));
```

---

## **Integration with Existing Services**

### **Automatic Context Generation (Future)**

Add context generation hooks to your services:

```typescript
// In ledger-writer service
async createVendor(dto: CreateVendorDto) {
  const vendor = await this.vendorRepository.save(dto);

  // Trigger async context generation
  await this.contextService.generateContext({
    entity_type: 'vendor',
    entity_id: vendor.vendor_id,
    tenant_id: vendor.tenant_id,
    entity_data: vendor
  });

  return vendor;
}
```

---

## **Coverage Monitoring**

Check context coverage regularly:

```bash
# Get stats
curl "http://localhost:8007/context-stats?tenant_id=00000000-0000-0000-0000-000000000001"

# Or query the view directly
docker exec -i airp-postgres psql -U airp_admin -d airp_master -c "SELECT * FROM ai_context_coverage;"
```

**Target Coverage:** >95% for production

---

## **Troubleshooting**

### **"AI service not available"**

```bash
# Check if ANTHROPIC_API_KEY is set
docker exec airp-ai-context-generator env | grep ANTHROPIC

# Set the key and restart
export ANTHROPIC_API_KEY=sk-ant-...
docker compose restart ai-context-generator
```

### **Slow context generation**

- Use batch generation for large datasets
- Consider generating context asynchronously via queue
- Monitor AI API rate limits

### **Search not finding records**

- Check if context has been generated: `SELECT COUNT(*) FROM vendors WHERE ai_context_summary IS NOT NULL;`
- Run batch generation if needed
- Verify keywords: `SELECT ai_context_keywords FROM vendors LIMIT 10;`

---

## **Future Enhancements**

1. **Real-Time Context Generation**: Auto-generate on record creation
2. **Context Refresh**: Periodic updates based on transaction history
3. **Learning from Usage**: Improve keywords based on search patterns
4. **Multi-Language Support**: Context in Arabic for UAE market
5. **Vector Search**: Qdrant integration for semantic similarity
6. **Anomaly Detection**: Use context to flag unusual patterns

---

## **API Reference**

### **AI Context Generator (Port 8007)**

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/generate-context` | POST | Generate context for single entity |
| `/batch-generate` | POST | Batch generate for multiple entities |
| `/context-stats` | GET | Get coverage statistics |

### **AI Query Parser (Port 8006)**

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/parse` | POST | Parse natural language query |
| `/format-response` | POST | Format results with context |

---

## **Version History**

### **v2.11.0** (Current)
- Initial release of AI Context feature
- Database migration for context fields
- AI Context Generator service
- Enhanced AI Query Parser with semantic search
- Helper scripts for setup and batch generation

---

**Questions or issues?** Check logs:
```bash
docker logs airp-ai-context-generator
docker logs airp-ai-query-parser
```
