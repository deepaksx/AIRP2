# AIRP v2.0 - Quick Start Guide

Get AIRP running in **under 5 minutes**.

## Prerequisites

- Docker Desktop installed and running
- 8GB RAM minimum
- 20GB free disk space
- *Optional*: Anthropic API key for full AI features

## Step-by-Step

### 1. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Optional: Edit .env and add your API key
# ANTHROPIC_API_KEY=sk-ant-your-key-here
```

### 2. Start Services

```bash
# Start all infrastructure and services
docker compose up -d

# Wait ~60 seconds for all services to initialize
# Watch the logs
docker compose logs -f
```

### 3. Verify Services

Check that all services are healthy:

```bash
docker compose ps
```

You should see all services in "healthy" status.

### 4. Run the Demo

```bash
# Make the demo script executable (Linux/Mac)
chmod +x examples/demo/demo_script.sh

# Run the end-to-end demo
./examples/demo/demo_script.sh
```

**Windows users**: Use Git Bash or WSL to run the script, or execute the curl commands manually from the README.

### 5. Explore the System

| Service | URL | Credentials |
|---------|-----|-------------|
| **Ledger Writer API** | http://localhost:3001/api/docs | None (open) |
| **AI Auto-Accounting** | http://localhost:8001/docs | None (open) |
| **Kafka Console** | http://localhost:8080 | None |
| **Grafana** | http://localhost:3100 | admin / admin |
| **PostgreSQL** | localhost:5432 | airp_admin / airp_secure_2024 |

## Manual Test: Invoice Classification

Test the AI service directly:

```bash
curl -X POST http://localhost:8001/classify \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
    "invoice_id": "test-001",
    "vendor_name": "Office Supplies Co",
    "transaction_type": "AP",
    "lines": [{
      "line_number": 1,
      "description": "Printer paper and pens",
      "amount": 500.00
    }]
  }'
```

Expected response:
```json
{
  "invoice_id": "test-001",
  "method": "hybrid",
  "suggestions": [{
    "account_code": "5500",
    "account_name": "Office Supplies",
    "confidence_score": 0.85,
    "reasoning": "..."
  }]
}
```

## Manual Test: Post Journal Entry

```bash
curl -X POST http://localhost:3001/journal-entries \
  -H "Content-Type: application/json" \
  -d '{
    "tenantId": "550e8400-e29b-41d4-a716-446655440000",
    "entryDate": "2024-01-15",
    "entryType": "Standard",
    "description": "Office Supplies Purchase",
    "lines": [
      {
        "accountCode": "5500",
        "debitAmount": 525.00,
        "creditAmount": 0,
        "description": "Office Supplies (incl. VAT)"
      },
      {
        "accountCode": "2100",
        "debitAmount": 0,
        "creditAmount": 525.00,
        "description": "Accounts Payable"
      }
    ]
  }'
```

## Troubleshooting

### Services won't start
```bash
# Check Docker resources
docker system df

# Clean up old containers
docker compose down -v
docker system prune -f

# Retry
docker compose up -d
```

### Database connection errors
```bash
# Verify Postgres is healthy
docker compose exec postgres pg_isready -U airp_admin

# Check logs
docker compose logs postgres
```

### AI service not responding
```bash
# Check if service is running
curl http://localhost:8001/health

# View logs
docker compose logs ai-auto-accounting

# Note: AI works in demo mode without API keys (rule-based fallback)
```

## Next Steps

1. **Read the full README.md** - Complete architecture and features
2. **Explore Swagger docs** - Interactive API documentation
3. **Check Grafana dashboards** - System metrics and monitoring
4. **Query the event store** - Complete audit trail

```bash
# Connect to database
docker compose exec postgres psql -U airp_admin -d airp_master

# Query event store
SELECT event_type, COUNT(*) FROM event_store GROUP BY event_type;

# View journal entries
SELECT * FROM journal_entries ORDER BY created_at DESC LIMIT 10;
```

## Clean Up

```bash
# Stop all services
docker compose down

# Remove all data (WARNING: destructive)
docker compose down -v
```

---

**Ready to dive deeper?** See the full [README.md](README.md) for complete documentation.

**Questions?** Open an issue or contact support@airp.ai

