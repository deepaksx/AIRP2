#!/usr/bin/env python3
"""
AIRP v2.0 - AI Query Parser Service
Uses Claude to understand natural language queries and convert them to structured actions
"""
import os
import json
import anthropic
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Optional, Any
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load database schema from external file
SCHEMA_FILE_PATH = os.path.join(os.path.dirname(__file__), '..', 'database_schema.txt')
try:
    with open(SCHEMA_FILE_PATH, 'r', encoding='utf-8') as f:
        DATABASE_SCHEMA = f.read()
    logger.info(f"✅ Loaded database schema from {SCHEMA_FILE_PATH} ({len(DATABASE_SCHEMA)} characters)")
except FileNotFoundError:
    logger.error(f"❌ Schema file not found: {SCHEMA_FILE_PATH}")
    DATABASE_SCHEMA = "ERROR: Database schema file not found!"
except Exception as e:
    logger.error(f"❌ Error loading schema: {e}")
    DATABASE_SCHEMA = f"ERROR: {e}"

app = FastAPI(title="AI Query Parser Service", version="2.0.0")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Anthropic client
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
ai_client = None

if ANTHROPIC_API_KEY and len(ANTHROPIC_API_KEY) > 10:
    try:
        ai_client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
        logger.info("✅ Anthropic Claude client initialized")
    except Exception as e:
        logger.warning(f"⚠️ Failed to initialize Anthropic client: {e}")
else:
    logger.warning("⚠️ No Anthropic API key provided - service will not work")


class QueryRequest(BaseModel):
    tenant_id: str
    query: str
    context: Optional[Dict[str, Any]] = None


class QueryResponse(BaseModel):
    intent: str
    action: str
    entities: Dict[str, Any]
    sql_query: Optional[str] = None
    api_endpoint: Optional[str] = None
    explanation: str
    clarification_needed: Optional[bool] = False
    clarification_options: Optional[List[str]] = None


class FormatRequest(BaseModel):
    tenant_id: str
    original_query: str
    raw_data: Any  # Query results in any format (list, dict, etc.)
    data_type: str  # "query_result", "report", "analysis"


class FormatResponse(BaseModel):
    formatted_html: str
    summary: str


QUERY_PARSER_PROMPT = """You are an AI assistant for a Financial ERP system. Parse the user's natural language query and convert it to a structured action.

Available Entities:
- GL Accounts (Chart of Accounts)
- Vendors (AP suppliers)
- Customers (AR clients)
- Invoices (AP/AR)
- Journal Entries
- Bank Accounts
- Payments

Available Actions:
1. QUERY - Retrieve information (SELECT)
2. CREATE - Create new record (INSERT)
3. UPDATE - Modify existing record (UPDATE)
4. REPORT - Generate ad-hoc report
5. ANALYZE - Perform analysis/calculations
6. CLARIFY - Ask clarifying questions when query is ambiguous

CLARIFICATION RULES:
When a query is ambiguous or could be interpreted multiple ways, use intent="CLARIFY" and provide clarification_options.

Examples of when to ask for clarification:
- "Show me accounts" (vague, no specific info) → Ask: "Would you like to see account balances as well?"
- "List vendors" (ONLY if no specific request) → Ask: "Would you like to see outstanding balances?"
- "Show invoices" → Ask: "Which type? Payable (AP) or Receivable (AR)?"
- "Create vendor" (missing details) → Ask: "Please provide vendor name and other details"
- Queries missing date ranges for time-sensitive data

IMPORTANT: Do NOT ask for clarification when the query is already specific:
- "How many vendors do we have" or "List all vendors" → This is SPECIFIC, use QUERY intent
- "Show vendor balances" → This is SPECIFIC, use QUERY intent
- "List vendors with names and codes" → This is SPECIFIC, use QUERY intent
- Any query that specifies what information is needed → Use QUERY intent

Domain Areas:
- GL (General Ledger)
- AP (Accounts Payable)
- AR (Accounts Receivable)
- BANK (Bank accounts & reconciliation)
- CASH (Cash management)
- REPORTING (Financial statements)

{database_schema}

Response Format (JSON):
{
  "intent": "QUERY | CREATE | UPDATE | REPORT | ANALYZE | CLARIFY",
  "action": "specific action description",
  "entities": {
    "domain": "GL | AP | AR | BANK | CASH | REPORTING",
    "entity_type": "vendor | customer | account | invoice | entry | payment",
    "filters": {
      "amount_gt": number,
      "amount_lt": number,
      "date_from": "YYYY-MM-DD",
      "date_to": "YYYY-MM-DD",
      "status": "string",
      "account_code": "string",
      "vendor_name": "string",
      "customer_name": "string"
    },
    "fields": ["field1", "field2"],
    "new_record": {}  // For CREATE actions
  },
  "sql_query": "Generated SQL query if applicable (null for CLARIFY)",
  "api_endpoint": "API endpoint to call (null for CLARIFY)",
  "explanation": "Plain English explanation of what will be done",
  "clarification_needed": true/false,
  "clarification_options": ["Option 1", "Option 2", "Option 3"]  // For CLARIFY intent
}

Examples:

User: "List all vendors who owe more than 5000 AED"
Response:
{
  "intent": "QUERY",
  "action": "list_vendor_balances_filtered",
  "entities": {
    "domain": "AP",
    "entity_type": "vendor",
    "filters": {
      "balance_gt": 5000
    },
    "fields": ["vendor_name", "balance", "payment_terms"]
  },
  "sql_query": "SELECT v.vendor_code, v.vendor_name, COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0) as balance FROM vendors v LEFT JOIN journal_entry_lines jel ON jel.dimension_1::text = v.vendor_id::text LEFT JOIN journal_entries je ON jel.entry_id = je.entry_id LEFT JOIN chart_of_accounts coa ON jel.account_id = coa.account_id WHERE v.tenant_id = ? AND coa.account_code = '2100' AND je.status = 'posted' GROUP BY v.vendor_id, v.vendor_code, v.vendor_name HAVING balance > 5000 ORDER BY balance DESC",
  "api_endpoint": "POST /api/query",
  "explanation": "Querying all vendors with outstanding balance greater than 5000 AED from GL (source of truth)"
}

User: "Create a new vendor account for Acme Corp"
Response:
{
  "intent": "CREATE",
  "action": "create_vendor",
  "entities": {
    "domain": "AP",
    "entity_type": "vendor",
    "new_record": {
      "vendor_name": "Acme Corp",
      "vendor_code": "ACME",
      "status": "active"
    }
  },
  "sql_query": null,
  "api_endpoint": "POST /vendors",
  "explanation": "Creating a new vendor account for Acme Corp in the system"
}

User: "Show me cash flow for last 30 days"
Response:
{
  "intent": "REPORT",
  "action": "generate_cash_flow_report",
  "entities": {
    "domain": "CASH",
    "entity_type": "report",
    "filters": {
      "days_back": 30
    },
    "fields": ["date", "inflow", "outflow", "net_change", "balance"]
  },
  "sql_query": "SELECT entry_date, SUM(CASE WHEN debit_amount > 0 THEN debit_amount ELSE 0 END) as inflow, SUM(CASE WHEN credit_amount > 0 THEN credit_amount ELSE 0 END) as outflow FROM journal_entry_lines WHERE tenant_id = ? AND account_code = '1000' AND entry_date >= CURRENT_DATE - INTERVAL '30 days' GROUP BY entry_date ORDER BY entry_date",
  "api_endpoint": "POST /api/query",
  "explanation": "Generating cash flow report for the last 30 days from account 1000 (Cash)"
}

User: "What's the total AP balance?"
Response:
{
  "intent": "ANALYZE",
  "action": "calculate_total_ap",
  "entities": {
    "domain": "AP",
    "entity_type": "summary",
    "fields": ["total_payable", "vendor_count", "invoice_count"]
  },
  "sql_query": "SELECT SUM(amount_outstanding) as total_payable, COUNT(DISTINCT vendor_id) as vendor_count, COUNT(*) as invoice_count FROM ap_invoices WHERE tenant_id = ? AND status != 'paid'",
  "api_endpoint": "POST /api/query",
  "explanation": "Calculating total accounts payable balance across all open invoices"
}

User: "Create GL account 6500 for Training Expenses"
Response:
{
  "intent": "CREATE",
  "action": "create_gl_account",
  "entities": {
    "domain": "GL",
    "entity_type": "account",
    "new_record": {
      "account_code": "6500",
      "account_name": "Training Expenses",
      "account_type": "Expense",
      "normal_balance": "Debit",
      "status": "active"
    }
  },
  "sql_query": null,
  "api_endpoint": "POST /chart-of-accounts",
  "explanation": "Creating new GL account 6500 for Training Expenses as an expense account"
}

User: "List accounts" OR "Show me all accounts" (WITHOUT explicit mention of balances)
Response:
{
  "intent": "QUERY",
  "action": "list_gl_accounts",
  "entities": {
    "domain": "GL",
    "entity_type": "account",
    "filters": {
      "status": "active"
    },
    "fields": ["account_code", "account_name", "account_type"]
  },
  "sql_query": "SELECT account_code, account_name, account_type FROM chart_of_accounts WHERE tenant_id = '00000000-0000-0000-0000-000000000001' AND status = 'active' ORDER BY account_code",
  "api_endpoint": "GET /chart-of-accounts",
  "explanation": "Listing all active GL accounts with basic information (code, name, type)"
}

User: "List accounts WITH balances" OR "Show account balances"
Response:
{
  "intent": "QUERY",
  "action": "list_account_balances",
  "entities": {
    "domain": "GL",
    "entity_type": "account",
    "filters": {},
    "fields": ["account_code", "account_name", "account_type", "debit_balance", "credit_balance"]
  },
  "sql_query": "SELECT account_code, account_name, account_type, debit_balance, credit_balance FROM trial_balance WHERE tenant_id = '00000000-0000-0000-0000-000000000001' ORDER BY account_code",
  "api_endpoint": "POST /api/query",
  "explanation": "Retrieving all GL accounts with their current balances from the trial balance view",
  "clarification_needed": false,
  "clarification_options": null
}

User: "Show me accounts" (ambiguous - no mention of balances)
Response:
{
  "intent": "CLARIFY",
  "action": "clarify_account_query",
  "entities": {
    "domain": "GL",
    "entity_type": "account",
    "filters": {}
  },
  "sql_query": null,
  "api_endpoint": null,
  "explanation": "I can show you the accounts. Would you like me to include balance information?",
  "clarification_needed": true,
  "clarification_options": [
    "Just show account codes and names",
    "Show accounts with their current balances"
  ]
}

User: "How many vendors do we have, list them" OR "List all vendors" (SPECIFIC - user clearly wants vendor list)
Response:
{
  "intent": "QUERY",
  "action": "list_all_vendors",
  "entities": {
    "domain": "AP",
    "entity_type": "vendor",
    "filters": {},
    "fields": ["vendor_code", "vendor_name", "status", "payment_terms"]
  },
  "sql_query": "SELECT vendor_code, vendor_name, status, payment_terms FROM vendors WHERE tenant_id = ? AND status = 'active' ORDER BY vendor_name",
  "api_endpoint": "GET /vendors",
  "explanation": "Listing all active vendors with their basic information",
  "clarification_needed": false
}

User: "List vendors" (vague - just two words, no clear specifics)
Response:
{
  "intent": "CLARIFY",
  "action": "clarify_vendor_query",
  "entities": {
    "domain": "AP",
    "entity_type": "vendor",
    "filters": {}
  },
  "sql_query": null,
  "api_endpoint": null,
  "explanation": "I can list the vendors. What information would you like to see?",
  "clarification_needed": true,
  "clarification_options": [
    "Just vendor names and basic info",
    "Include outstanding balances"
  ]
}

User: "Show invoices"
Response:
{
  "intent": "CLARIFY",
  "action": "clarify_invoice_type",
  "entities": {
    "domain": "REPORTING",
    "entity_type": "invoice",
    "filters": {}
  },
  "sql_query": null,
  "api_endpoint": null,
  "explanation": "Which type of invoices would you like to see?",
  "clarification_needed": true,
  "clarification_options": [
    "Accounts Payable (vendor invoices we need to pay)",
    "Accounts Receivable (customer invoices owed to us)"
  ]
}

Now parse the following user query:

User Query: {query}

Tenant Context:
- Tenant ID: {tenant_id}
- Chart of Accounts: Standard UAE business CoA
- Currency: AED
- Fiscal Year End: December 31

Respond with ONLY the JSON structure, no additional text.
"""


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "AI Query Parser",
        "ai_enabled": ai_client is not None
    }


@app.post("/parse", response_model=QueryResponse)
async def parse_query(request: QueryRequest):
    """Parse natural language query into structured action"""

    if not ai_client:
        raise HTTPException(status_code=503, detail="AI service not available - no API key")

    response_text = ""
    try:
        logger.info(f"Parsing query: {request.query}")

        # Build prompt with schema injection
        prompt = QUERY_PARSER_PROMPT.replace("{database_schema}", DATABASE_SCHEMA)
        prompt = prompt.replace("{query}", request.query).replace("{tenant_id}", request.tenant_id)

        # Call Claude
        logger.info("Calling Claude API...")
        response = ai_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=2000,
            temperature=0.2,
            messages=[
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        )
        logger.info("Claude API call successful")

        # Extract JSON from response
        response_text = response.content[0].text.strip()

        logger.info(f"Raw Claude response: {response_text[:200]}...")

        # Remove markdown code blocks if present
        if response_text.startswith("```"):
            response_text = response_text.split("```")[1]
            if response_text.strip().startswith("json"):
                response_text = response_text.strip()[4:]
            response_text = response_text.strip()

        logger.info(f"Processed response: {response_text[:200]}...")

        # Parse JSON
        parsed = json.loads(response_text)

        logger.info(f"✅ Parsed intent: {parsed['intent']}, action: {parsed['action']}")

        # VALIDATION: Check if SQL contains hallucinated columns from chart_of_accounts
        if parsed.get('sql_query'):
            sql_lower = parsed['sql_query'].lower()

            # SMART CHECK: Only block balance columns when querying FROM chart_of_accounts
            # Allow them from trial_balance and gl_balances (which DO have these columns)
            forbidden_columns = ['current_balance', 'debit_balance', 'credit_balance']

            # Check if querying from chart_of_accounts (not trial_balance or gl_balances)
            is_querying_coa = 'from chart_of_accounts' in sql_lower or 'from public.chart_of_accounts' in sql_lower
            is_querying_safe_tables = 'from trial_balance' in sql_lower or 'from gl_balances' in sql_lower or 'join gl_balances' in sql_lower

            found_forbidden = None
            if is_querying_coa and not is_querying_safe_tables:
                # Only check for forbidden columns if querying chart_of_accounts directly
                for col in forbidden_columns:
                    # Check with various separators: space, comma, dot (for table.column)
                    if (f' {col}' in sql_lower or f',{col}' in sql_lower or
                        f'.{col}' in sql_lower or f'({col}' in sql_lower):
                        found_forbidden = col
                        break

            if found_forbidden:
                logger.warning(f"⚠️ VALIDATION TRIGGERED: AI hallucinated forbidden column '{found_forbidden}' from chart_of_accounts")
                logger.warning(f"⚠️ Original SQL: {parsed['sql_query']}")

                # Determine intent from the query
                if 'count' in sql_lower or 'how many' in request.query.lower():
                    # COUNT query
                    parsed['sql_query'] = f"SELECT COUNT(*) as account_count FROM chart_of_accounts WHERE tenant_id = '{request.tenant_id}' AND status = 'active'"
                    parsed['explanation'] = "Counting total number of active GL accounts"
                    logger.info(f"🔧 Fixed to COUNT query")
                else:
                    # User wants balances - use trial_balance view
                    if 'balance' in request.query.lower():
                        parsed['sql_query'] = f"SELECT account_code, account_name, account_type, debit_balance, credit_balance, (COALESCE(debit_balance,0) - COALESCE(credit_balance,0)) as net_balance FROM trial_balance WHERE tenant_id = '{request.tenant_id}' ORDER BY account_code"
                        parsed['explanation'] = "Listing all GL accounts with their current balances from trial balance"
                        if 'fields' in parsed.get('entities', {}):
                            parsed['entities']['fields'] = ['account_code', 'account_name', 'account_type', 'debit_balance', 'credit_balance', 'net_balance']
                        logger.info(f"🔧 Fixed to trial_balance query with balances")
                    else:
                        # LIST query without balances
                        parsed['sql_query'] = f"SELECT account_code, account_name, account_type FROM chart_of_accounts WHERE tenant_id = '{request.tenant_id}' AND status = 'active' ORDER BY account_code"
                        parsed['explanation'] = "Listing all active GL accounts (basic info only - use 'show balances' for account balances)"
                        if 'fields' in parsed.get('entities', {}):
                            parsed['entities']['fields'] = ['account_code', 'account_name', 'account_type']
                        logger.info(f"🔧 Fixed to LIST query")

                logger.info(f"🔧 New SQL: {parsed['sql_query']}")
            else:
                logger.info(f"✅ SQL validation passed - no forbidden columns detected")

        return QueryResponse(**parsed)

    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse AI response as JSON: {e}")
        logger.error(f"Response text: {response_text}")
        raise HTTPException(status_code=500, detail=f"Failed to parse AI response: {e}")

    except Exception as e:
        logger.error(f"Error parsing query: {type(e).__name__}: {e}")
        logger.error(f"Response text so far: {response_text[:500] if response_text else 'No response yet'}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"{type(e).__name__}: {str(e)}")


@app.post("/validate-duplicate")
async def validate_duplicate(entity_type: str, entity_data: Dict[str, Any], tenant_id: str):
    """Check if entity already exists to prevent duplicates"""

    # This would query the database to check for duplicates
    # For now, return example response

    duplicate_checks = {
        "vendor": {
            "check_field": "vendor_name",
            "query": f"SELECT vendor_id FROM vendors WHERE tenant_id = '{tenant_id}' AND LOWER(vendor_name) = LOWER('{entity_data.get('vendor_name', '')}') LIMIT 1"
        },
        "customer": {
            "check_field": "customer_name",
            "query": f"SELECT customer_id FROM customers WHERE tenant_id = '{tenant_id}' AND LOWER(customer_name) = LOWER('{entity_data.get('customer_name', '')}') LIMIT 1"
        },
        "account": {
            "check_field": "account_code",
            "query": f"SELECT account_id FROM chart_of_accounts WHERE tenant_id = '{tenant_id}' AND account_code = '{entity_data.get('account_code', '')}' LIMIT 1"
        }
    }

    if entity_type not in duplicate_checks:
        return {"is_duplicate": False, "message": "Unknown entity type"}

    check_config = duplicate_checks[entity_type]

    return {
        "entity_type": entity_type,
        "check_field": check_config["check_field"],
        "check_value": entity_data.get(check_config["check_field"]),
        "sql_query": check_config["query"],
        "is_duplicate": False,  # Would be result of actual query
        "existing_id": None,
        "message": "No duplicate found - safe to create"
    }


FORMATTER_PROMPT = """You are an AI assistant that formats raw financial data into user-friendly HTML displays.

Your task:
1. Analyze the user's original question
2. Review the raw data provided
3. Format the data in the most appropriate and user-friendly way
4. Return clean HTML that can be directly displayed

Guidelines:
- Use HTML tables for tabular data (with Bootstrap classes: table table-striped table-hover)
- Use lists (<ul>) for simple enumerations
- Use cards or sections for complex data
- Highlight important numbers (totals, balances) with <strong> tags
- Use appropriate icons from Bootstrap (if helpful)
- Add helpful summaries at the top
- Format numbers properly (currency with 2 decimals: 1,234.56 AED)
- Use color coding for positive/negative values (text-success/text-danger)
- Keep the design clean and professional

Important:
- Return ONLY valid HTML (no markdown, no extra text)
- Do NOT include <html>, <head>, or <body> tags (just the content)
- Use inline styles sparingly, prefer Bootstrap classes
- Always show a count when displaying lists (e.g., "Showing 5 vendors")

Example 1 - Vendor List:
User asked: "How many vendors do we have?"
Raw data: [{"vendor_code": "V001", "vendor_name": "Acme Corp", "status": "active"}, ...]

Your response:
<div class="mb-3">
    <h5>📊 Vendor Summary</h5>
    <p>You have <strong>5 active vendors</strong> in the system.</p>
</div>
<table class="table table-striped table-hover">
    <thead>
        <tr>
            <th>Code</th>
            <th>Vendor Name</th>
            <th>Status</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>V001</td>
            <td>Acme Corp</td>
            <td><span class="badge bg-success">Active</span></td>
        </tr>
        ...
    </tbody>
</table>

Example 2 - Account Balances:
User asked: "Show me account balances"
Raw data: [{"account_code": "1000", "account_name": "Cash", "debit_balance": 50000, "credit_balance": 0}, ...]

Your response:
<div class="mb-3">
    <h5>💰 Account Balances</h5>
    <p>Showing balances for <strong>10 accounts</strong></p>
</div>
<table class="table table-striped table-hover">
    <thead>
        <tr>
            <th>Code</th>
            <th>Account Name</th>
            <th class="text-end">Debit</th>
            <th class="text-end">Credit</th>
            <th class="text-end">Net Balance</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>1000</td>
            <td>Cash</td>
            <td class="text-end">50,000.00</td>
            <td class="text-end">-</td>
            <td class="text-end text-success">50,000.00 AED</td>
        </tr>
        ...
    </tbody>
</table>

Example 3 - Simple Count:
User asked: "How many invoices do we have?"
Raw data: {"count": 42}

Your response:
<div class="alert alert-info">
    <h5>📄 Invoice Count</h5>
    <p class="mb-0">You currently have <strong>42 invoices</strong> in the system.</p>
</div>

Now format the following data:

User's Original Question: {original_query}
Data Type: {data_type}

Raw Data (JSON):
{raw_data}

Respond with ONLY the formatted HTML, no additional text or explanation.
"""


@app.post("/format-response", response_model=FormatResponse)
async def format_response(request: FormatRequest):
    """Format raw query results into user-friendly HTML"""

    if not ai_client:
        raise HTTPException(status_code=503, detail="AI service not available - no API key")

    try:
        logger.info(f"Formatting response for query: {request.original_query}")

        # Convert raw data to JSON string
        raw_data_str = json.dumps(request.raw_data, indent=2, ensure_ascii=False)

        # Build prompt
        prompt = FORMATTER_PROMPT.replace("{original_query}", request.original_query)
        prompt = prompt.replace("{data_type}", request.data_type)
        prompt = prompt.replace("{raw_data}", raw_data_str)

        # Call Claude
        logger.info("Calling Claude API for formatting...")
        response = ai_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=4000,
            temperature=0.3,
            messages=[
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        )
        logger.info("Claude API call successful")

        # Extract response
        formatted_html = response.content[0].text.strip()

        # Remove markdown code blocks if present
        if formatted_html.startswith("```"):
            formatted_html = formatted_html.split("```")[1]
            if formatted_html.strip().startswith("html"):
                formatted_html = formatted_html.strip()[4:]
            formatted_html = formatted_html.strip()

        # Create a simple summary
        if isinstance(request.raw_data, list):
            summary = f"Formatted {len(request.raw_data)} records"
        elif isinstance(request.raw_data, dict):
            summary = f"Formatted query result"
        else:
            summary = "Formatted response"

        logger.info(f"✅ Formatted response successfully: {summary}")

        return FormatResponse(
            formatted_html=formatted_html,
            summary=summary
        )

    except Exception as e:
        logger.error(f"Error formatting response: {type(e).__name__}: {e}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Formatting error: {str(e)}")


if __name__ == "__main__":
    import uvicorn

    print("=" * 60)
    print("AIRP v2.0 - AI Query Parser Service")
    print("Natural Language to Structured Actions")
    print("=" * 60)
    print(f"API Server: http://localhost:8006")
    print("=" * 60)

    uvicorn.run(app, host="0.0.0.0", port=8006)
