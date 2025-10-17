# AIRP v2.0 - Complete Deployment Guide

## 🚀 Quick Start (3 Steps)

### 1. Start All Infrastructure & Services

```bash
# Start everything with one command
docker compose -f docker-compose.dev.yml up -d

# Wait for all services to be healthy (may take 2-3 minutes)
docker compose -f docker-compose.dev.yml ps
```

### 2. Initialize Database

```powershell
# Windows PowerShell
.\scripts\init-database.ps1

# OR Windows Command Prompt
.\scripts\init-database.bat
```

### 3. Test All Services

```powershell
# Run comprehensive test suite
.\scripts\test-all-services.ps1
```

---

## 📦 What Gets Deployed

### Infrastructure (5 containers)
- **PostgreSQL 15** - Event store & read models (port 5432)
- **Kafka/Redpanda** - Event bus (ports 19092, 18081, 18082, 8080)
- **Redis** - Caching layer (port 6379)
- **Qdrant** - Vector database for RAG (port 6333)

### Core Services (8 NestJS containers)
- **ledger-writer** (port 3001) - Event-sourced GL & journal entries
- **projection-service** (port 3002) - Event consumer for read models
- **ap-service** (port 3003) - Accounts Payable management
- **ar-service** (port 3004) - Accounts Receivable management
- **treasury-service** (port 3005) - Cash management & bank reconciliation
- **fpna-service** (port 3006) - Budgeting & variance analysis
- **policy-engine** (port 3007) - Business rules & approval workflows
- **reporting-service** (port 3008) - Financial statements & reports

### AI Services (5 FastAPI/Python containers)
- **ai-auto-accounting** (port 8001) - GL code classification
- **ai-recon** (port 8002) - Bank reconciliation matching
- **ai-forecast** (port 8003) - Cash flow forecasting
- **ai-narrative** (port 8004) - Executive summaries
- **ai-policy-advisor** (port 8005) - IFRS/GAAP/VAT guidance (RAG)

**Total: 18 containers**

---

## 🔧 Configuration

### Environment Variables

Create `.env` file in the root directory:

```env
# AI Provider (optional - works in demo mode without)
ANTHROPIC_API_KEY=your_api_key_here
OPENAI_API_KEY=your_api_key_here
AI_PROVIDER=anthropic

# Database (defaults are fine for development)
POSTGRES_USER=airp_admin
POSTGRES_PASSWORD=airp_secure_2024
POSTGRES_DB=airp_master

# Timezone
TZ=Asia/Dubai
```

---

## 📊 Health Check URLs

### Quick Health Check (All Services)

```powershell
# Check all services at once
.\scripts\test-all-services.ps1
```

### Individual Service Health Checks

```
http://localhost:3001/health - Ledger Writer
http://localhost:3002/health - Projection Service
http://localhost:3003/health - AP Service
http://localhost:3004/health - AR Service
http://localhost:3005/health - Treasury Service
http://localhost:3006/health - FP&A Service
http://localhost:3007/health - Policy Engine
http://localhost:3008/health - Reporting Service

http://localhost:8001/health - AI Auto-Accounting
http://localhost:8002/health - AI Reconciliation
http://localhost:8003/health - AI Forecasting
http://localhost:8004/health - AI Narrative
http://localhost:8005/health - AI Policy Advisor

http://localhost:8080 - Kafka Console UI
http://localhost:6333/dashboard - Qdrant Dashboard
```

---

## 🧪 Testing & Demo

### Test Data

The initialization script creates:
- **Test Tenant**: Demo Company LLC (ID: 00000000-0000-0000-0000-000000000001)
- **Chart of Accounts**: 7 test accounts (Cash, A/R, A/P, Revenue, COGS, Office Supplies, IT & Software)
- **Test Vendor**: ABC Suppliers LLC
- **Test Customer**: XYZ Trading LLC
- **Test Bank Account**: Emirates NBD

### Example API Calls

#### 1. AI Auto-Accounting

```powershell
# Classify invoice line items
$body = @{
    tenant_id = "00000000-0000-0000-0000-000000000001"
    invoice_id = "test-001"
    transaction_type = "AP"
    lines = @(
        @{
            line_number = 1
            description = "Office supplies - printer paper and pens"
            amount = 150.00
            quantity = 1
        }
    )
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8001/classify" -Method POST -Body $body -ContentType "application/json"
```

#### 2. AI Policy Advisor

```powershell
# Ask accounting policy question
$body = @{
    tenant_id = "00000000-0000-0000-0000-000000000001"
    query = "When should revenue be recognized for a service contract?"
    context_type = "ifrs"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8005/query" -Method POST -Body $body -ContentType "application/json"
```

#### 3. Cash Flow Forecasting

```powershell
# Generate 30-day cash flow forecast
$body = @{
    tenant_id = "00000000-0000-0000-0000-000000000001"
    account_id = "40000000-0000-0000-0000-000000000001"
    current_balance = 500000
    forecast_days = 30
    historical_data = @(
        @{ date = "2025-01-01"; inflows = 50000; outflows = 30000; net_cash_flow = 20000 }
        @{ date = "2025-01-02"; inflows = 45000; outflows = 28000; net_cash_flow = 17000 }
        @{ date = "2025-01-03"; inflows = 52000; outflows = 31000; net_cash_flow = 21000 }
    )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "http://localhost:8003/forecast" -Method POST -Body $body -ContentType "application/json"
```

#### 4. Trial Balance Report

```powershell
# Get trial balance
Invoke-RestMethod -Uri "http://localhost:8008/reports/trial-balance?tenant_id=00000000-0000-0000-0000-000000000001&period_end_date=2025-01-31"
```

#### 5. Bank Reconciliation

```powershell
# Reconcile bank transactions
$body = @{
    tenant_id = "00000000-0000-0000-0000-000000000001"
    account_id = "40000000-0000-0000-0000-000000000001"
    bank_transactions = @(
        @{
            transaction_id = "bank-001"
            transaction_date = "2025-01-15"
            description = "Customer payment received"
            amount = 5000
            transaction_type = "credit"
        }
    )
    gl_transactions = @(
        @{
            entry_id = "gl-001"
            entry_date = "2025-01-15"
            description = "Payment from XYZ Trading"
            amount = 5000
            account_code = "1000"
            account_name = "Cash"
        }
    )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "http://localhost:8002/reconcile" -Method POST -Body $body -ContentType "application/json"
```

---

## 🛑 Stopping Services

```bash
# Stop all services
docker compose -f docker-compose.dev.yml down

# Stop and remove volumes (CAUTION: Deletes all data)
docker compose -f docker-compose.dev.yml down -v
```

---

## 🔍 Troubleshooting

### Service won't start

```bash
# Check logs
docker compose -f docker-compose.dev.yml logs <service-name>

# Example:
docker compose -f docker-compose.dev.yml logs ledger-writer
docker compose -f docker-compose.dev.yml logs ai-auto-accounting
```

### Database connection issues

```bash
# Verify PostgreSQL is healthy
docker exec airp-postgres pg_isready -U airp_admin -d airp_master

# Connect to database manually
docker exec -it airp-postgres psql -U airp_admin -d airp_master

# Check tables
\dt
```

### Reset everything

```bash
# Nuclear option: Remove everything and start fresh
docker compose -f docker-compose.dev.yml down -v
docker system prune -a --volumes -f
docker compose -f docker-compose.dev.yml up -d
.\scripts\init-database.ps1
```

---

## 📈 Monitoring

### Prometheus Metrics

All services expose Prometheus metrics at `/metrics`:

```
http://localhost:3001/metrics
http://localhost:8001/metrics
...
```

### Service Logs

```bash
# Tail logs for all services
docker compose -f docker-compose.dev.yml logs -f

# Tail specific service
docker compose -f docker-compose.dev.yml logs -f ledger-writer

# Show last 100 lines
docker compose -f docker-compose.dev.yml logs --tail=100 ai-auto-accounting
```

---

## 🎯 Next Steps

1. **Explore the APIs**: Try the example calls above
2. **Check Kafka Console**: http://localhost:8080 to see events flowing
3. **Review the Code**: All services are in `services/` directory
4. **Read the Docs**: See `README.md` and `WHAT_IS_AIRP.md`
5. **Configure AI**: Add your Anthropic API key to `.env` for full AI functionality

---

## 💡 Pro Tips

- **Demo Mode**: Works without AI API keys (uses fallback logic)
- **Hot Reload**: NestJS and FastAPI services support live code updates
- **Database Access**: Use any PostgreSQL client (localhost:5432, user: airp_admin)
- **Event Streaming**: Check Kafka Console UI to see events in real-time
- **Vector Search**: Qdrant dashboard shows RAG knowledge base

---

## 📚 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      API Gateway (Future)                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      CORE SERVICES (NestJS)                  │
├─────────────────┬────────────┬──────────────┬───────────────┤
│  Ledger Writer  │   AP/AR    │   Treasury   │   Reporting   │
│  (Event Source) │  Services  │   FP&A       │   Policy      │
└────────┬────────┴─────┬──────┴──────┬───────┴───────┬───────┘
         │              │             │               │
         │              │             │               │
         ▼              ▼             ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│                     EVENT BUS (Kafka)                        │
└─────────────────────────────────────────────────────────────┘
         │              │             │               │
         ▼              ▼             ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│                   AI SERVICES (FastAPI)                      │
├──────────────┬───────────┬────────────┬─────────────────────┤
│ Auto-Account │  Recon    │  Forecast  │  Narrative          │
│              │           │            │  Policy Advisor     │
└──────────────┴───────────┴────────────┴─────────────────────┘
         │              │             │               │
         ▼              ▼             ▼               ▼
┌──────────────┬──────────────┬──────────────┬───────────────┐
│  PostgreSQL  │    Redis     │    Kafka     │    Qdrant     │
│ (Event Store)│   (Cache)    │ (Event Bus)  │  (Vector DB)  │
└──────────────┴──────────────┴──────────────┴───────────────┘
```

---

## ✅ Success Criteria

When everything is working correctly, you should see:

- ✓ 18 healthy containers running
- ✓ All health checks return 200 OK
- ✓ Database schema loaded successfully
- ✓ Test tenant and data created
- ✓ AI classification returns account suggestions
- ✓ Trial balance report generates
- ✓ Events flowing through Kafka (visible in console UI)

---

## 🆘 Support

- **Issues**: Check logs first (`docker compose logs -f`)
- **Database**: Verify schema loaded (`\dt` in psql)
- **AI Services**: Work in demo mode without API keys
- **Reset**: `docker compose down -v` and start fresh

---

**Built with ❤️ by AIRP Team | Version 2.0.0**
