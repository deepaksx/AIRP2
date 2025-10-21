# AIRP v2.11.0 - Quick Start Guide

**Version**: v2.11.0
**Last Updated**: October 21, 2025

---

## 🚀 What's New in v2.11.0

### ChatERP - AI-Powered Natural Language Querying

Ask questions in plain English and get intelligent, context-aware answers:

- **"Who sells office supplies?"** → Get vendors by business type
- **"Which account for rent?"** → Find GL accounts by usage
- **"Show recurring payments"** → Discover transaction patterns
- **"Find IT vendors"** → Search by industry/category

---

## 🎯 Getting Started (5 Minutes)

### Step 1: Access AIRP

Open your browser and navigate to:
```
http://localhost:5000
```

### Step 2: Find AI Assistant

Look for the new menu section in the left sidebar:

```
🤖 6. AI ASSISTANT (NEW)
```

Click to expand the section.

### Step 3: Open ChatERP

Click on the highlighted item:
```
💬 ChatERP
```

### Step 4: Start Asking Questions

You'll see a clean chat interface. Type your question and click "Send":

**Example Questions**:

1. **Find Vendors**:
   ```
   Who sells office supplies?
   ```

2. **Discover Accounts**:
   ```
   Which account should I use for rent payments?
   ```

3. **Search Transactions**:
   ```
   Show me all payments to Dubai IT Solutions
   ```

4. **Analyze Patterns**:
   ```
   What are my recurring monthly expenses?
   ```

5. **Get Balances**:
   ```
   What's my cash balance?
   ```

---

## 💡 Pro Tips

### Natural Language Works Best

❌ **Don't**: Use technical terms
```
SELECT * FROM vendors WHERE vendor_name LIKE '%office%'
```

✅ **Do**: Ask naturally
```
Who sells office supplies?
```

### Be Specific When Needed

❌ **Too Vague**:
```
Show me stuff
```

✅ **Better**:
```
Show me all vendors in Dubai
```

✅ **Even Better**:
```
Show me IT vendors in Dubai with open balances
```

### Use Business Terms

The AI understands business context:

- "Office supplies" → Finds Emirates Office Supplies LLC
- "Rent" → Finds account 5200 - Rent Expense
- "Recurring" → Finds monthly/quarterly patterns
- "High spend" → Finds vendors with large transaction volumes

---

## 🎨 Interface Overview

### Main Components

```
┌─────────────────────────────────────────────────┐
│ 💬 ChatERP - AI Financial Assistant            │
│ AIRP v2.11.0 | Ask anything...    🟢 Connected │ ← Header
├─────────────────────────────────────────────────┤
│                                                 │
│  🤖 Welcome to ChatERP!                         │
│     Ask me anything about your financial data   │
│                                                 │
│  👤 Who sells office supplies?                  │ ← Your Question
│                                                 │
│  🤖 I found 2 vendors:                          │ ← AI Response
│     1. Emirates Office Supplies LLC             │
│     2. Dubai Stationery & More                  │
│                                                 │
│                                                 │
├─────────────────────────────────────────────────┤
│ Ask me anything... (e.g., "Post a journal    [Send] │ ← Input
└─────────────────────────────────────────────────┘
```

### Design Features

- **Clean Interface**: Full-width chat, no distractions
- **SAP Theme**: Professional light blue/white/gray design
- **Status Indicator**: Green dot shows AI is connected
- **Scrollable History**: See all previous conversations

---

## 📊 What You Can Ask

### 1. Master Data Queries

**Vendors**:
- "List all vendors"
- "Who sells [product/service]?"
- "Find vendors in Dubai"
- "Show IT vendors"

**Customers**:
- "List all customers"
- "Who are my high-value customers?"
- "Show customers with open balances"

**Chart of Accounts**:
- "Show all accounts"
- "Which account for [expense type]?"
- "List all bank accounts"
- "Find revenue accounts"

### 2. Transaction Queries

**Journal Entries**:
- "Show recent journal entries"
- "List entries posted today"
- "Find entries for account 5500"

**Invoices**:
- "Show unpaid AP invoices"
- "List overdue AR invoices"
- "Find invoices for [vendor name]"

**Payments**:
- "Show recent payments"
- "List payments to [vendor]"
- "Find bank transfers"

### 3. Balance & Reports

**Account Balances**:
- "What's my cash balance?"
- "Show bank account balances"
- "List all account balances"

**Sub-Ledgers**:
- "Show vendor ledger for [vendor name]"
- "Customer ledger for [customer name]"
- "AP aging report"
- "AR aging report"

**Financial Reports**:
- "Show trial balance"
- "Generate income statement"
- "Balance sheet"

### 4. Analysis & Insights

**Patterns**:
- "Show recurring expenses"
- "Find monthly utility payments"
- "List quarterly transactions"

**Trends**:
- "What are my top expenses?"
- "Who are my largest vendors?"
- "Analyze spending by category"

**Exceptions**:
- "Show overdue invoices"
- "Find unusual transactions"
- "List zero-balance accounts"

---

## 🔧 Advanced Features

### AI Context Awareness

Every record now has intelligent business context:

**Example - Vendor Context**:
```json
{
  "summary": "Office supplies vendor providing stationery and business essentials",
  "keywords": ["office", "supplies", "stationery", "paper"],
  "business_type": "supplier",
  "industry": "office_supplies",
  "typical_accounts": ["5500 - Office Supplies"]
}
```

This means:
- ✅ Searches understand business meaning
- ✅ Finds records even without exact name matches
- ✅ Suggests related accounts automatically
- ✅ Identifies patterns and relationships

### Semantic Search

**Traditional Search** (exact match):
```
Query: "Emirates Office Supplies LLC"
Result: ✅ Found (exact name match)

Query: "Office supplies vendor"
Result: ❌ Not found (name doesn't match)
```

**AI Context Search** (semantic):
```
Query: "Emirates Office Supplies LLC"
Result: ✅ Found

Query: "Office supplies vendor"
Result: ✅ Found (keyword match: "office", "supplies")

Query: "Stationery supplier"
Result: ✅ Found (related keyword: "stationery")
```

---

## 🛠️ Troubleshooting

### Issue: ChatERP won't load

**Solution**: Refresh the page
```
Press F5 or Ctrl+R
```

### Issue: AI shows "Disconnected"

**Solution**: Check AI services
```bash
docker compose ps | findstr "ai-"
```

All AI services should show "healthy" status.

### Issue: No results for my query

**Possible Reasons**:
1. **Context not generated yet** → Run: `.\run_generate_contexts.ps1`
2. **Service not running** → Check: `docker compose ps`
3. **Typo in query** → Rephrase and try again

### Issue: Slow response

**Normal**: First query may take 2-3 seconds (AI processing)
**If always slow**: Check network connection to AI service

---

## 📚 Additional Resources

### Documentation

- **Complete Feature Guide**: `AI_CONTEXT_FEATURE.md`
- **Integration Guide**: `CONTEXT_INTEGRATION_GUIDE.md`
- **Release Notes**: `RELEASE_NOTES_v2.11.0.md`
- **Deployment Checklist**: `DEPLOYMENT_CHECKLIST_v2.11.0.md`

### Other AI Tools

Explore other AI tools in the "6. AI ASSISTANT" menu:

1. **🏷️ AI Classification** - Auto-categorize transactions
2. **🔄 AI Reconciliation** - Bank statement matching
3. **📈 AI Cash Forecast** - Predict cash flow
4. **📝 AI Narratives** - Generate report summaries
5. **📋 AI Policy Advisor** - Get policy recommendations
6. **📊 Context Stats** - View AI coverage statistics

### API Documentation

For developers integrating ChatERP programmatically:

**Query Parser API**:
```
POST http://localhost:8006/parse-query
Body: {
  "query": "Who sells office supplies?",
  "tenant_id": "00000000-0000-0000-0000-000000000001"
}
```

**Context Generator API**:
```
POST http://localhost:8007/generate-context
Body: {
  "entity_type": "vendor",
  "entity_id": "uuid",
  "entity_data": {...}
}
```

---

## 🎯 Example Workflow

### Scenario: Posting an Office Supplies Expense

**Step 1**: Ask which account to use
```
User: "Which account for office supplies?"

AI: "Account 5500 - Office Supplies is typically used for
     office supplies expenses like stationery, paper, and
     printing costs."
```

**Step 2**: Find the vendor
```
User: "Who sells office supplies?"

AI: "I found 2 vendors:
     1. Emirates Office Supplies LLC (V001)
     2. Dubai Stationery & More (V008)"
```

**Step 3**: Check vendor details
```
User: "Show vendor ledger for Emirates Office Supplies"

AI: [Displays ledger with open balances, payment history]
```

**Step 4**: Post the entry (future feature)
```
User: "Post invoice 5000 AED from Emirates Office Supplies
       for office supplies"

AI: [Creates journal entry with correct accounts]
```

---

## 🎉 What Makes v2.11.0 Special

### Before v2.11.0

❌ Needed to know exact vendor names
❌ Required SQL knowledge for queries
❌ Manual account code lookup
❌ No business context understanding
❌ Separate dark-themed chat interface

### After v2.11.0

✅ Ask by business type: "office supplies vendor"
✅ Natural language queries: "Who sells...?"
✅ AI suggests accounts: "Use account 5500"
✅ Understands business relationships
✅ Unified professional SAP theme
✅ Integrated in main application menu
✅ Clean, focused chat interface

---

## 📞 Getting Help

### In-App Help

Click the help icon (?) in ChatERP for:
- Example queries
- Query syntax tips
- Keyboard shortcuts

### Documentation

Press F1 or type:
```
help
```

### Support

If you encounter issues:
1. Check service health: `docker compose ps`
2. Review logs: `docker compose logs -f ai-context-generator`
3. Restart services: `docker compose restart`

---

## 🚀 Next Steps

### Immediate

1. ✅ Try ChatERP with the example queries above
2. ✅ Explore other AI tools in the menu
3. ✅ Check Context Stats to see coverage

### Soon

1. Generate contexts for all existing data
2. Integrate into daily workflows
3. Provide feedback on accuracy
4. Request new features

### Future (v2.12.0)

1. Vector search (semantic similarity)
2. Multi-language support (Arabic + English)
3. Voice queries (speech-to-text)
4. Advanced analytics dashboards

---

## 📝 Feedback

We value your feedback! Please share:

- ✅ What queries work well
- ❌ What queries don't work
- 💡 Suggestions for improvement
- 🐛 Any bugs encountered

---

**Enjoy ChatERP v2.11.0!** 🎉

Your AI-powered financial assistant is ready to help you work smarter, not harder.

---

**Version**: v2.11.0
**Release Date**: October 21, 2025
**Support**: Check documentation in `/docs/` folder
**Status**: ✅ Ready for Use
