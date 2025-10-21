#!/usr/bin/env python3
"""
AIRP v2.11.0 - AI Context Generator Service
Generates intelligent context metadata for all master data and transactions
Enables semantic search and natural language querying
"""
import os
import json
import anthropic
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Optional, Any
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
import re

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="AI Context Generator Service", version="2.11.0")

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

# Database connection
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "database": os.getenv("DB_NAME", "airp_master"),
    "user": os.getenv("DB_USER", "airp_admin"),
    "password": os.getenv("DB_PASSWORD", "airp_secure_2024")
}


def get_db_connection():
    """Get database connection"""
    return psycopg2.connect(**DB_CONFIG)


# ============================================
# REQUEST/RESPONSE MODELS
# ============================================

class GenerateContextRequest(BaseModel):
    entity_type: str  # vendor, customer, account, journal_entry, ap_invoice, ar_invoice
    entity_id: str
    tenant_id: str
    entity_data: Dict[str, Any]  # The actual record data


class ContextResult(BaseModel):
    entity_type: str
    entity_id: str
    ai_context_summary: str
    ai_context_keywords: List[str]
    ai_context_entities: Dict[str, Any]
    ai_context_relationships: Dict[str, Any]
    ai_context_model_version: str


class BatchGenerateRequest(BaseModel):
    entity_type: str
    tenant_id: str
    limit: Optional[int] = 100


class BatchGenerateResponse(BaseModel):
    entity_type: str
    total_processed: int
    successful: int
    failed: int
    coverage_percentage: float


class ContextStatsResponse(BaseModel):
    total_records: int
    records_with_context: int
    coverage_percentage: float
    by_entity_type: Dict[str, Dict[str, Any]]


# ============================================
# CONTEXT GENERATION PROMPTS
# ============================================

VENDOR_CONTEXT_PROMPT = """You are analyzing a vendor record in a financial ERP system. Generate intelligent context metadata to help users find and understand this vendor using natural language queries.

Vendor Record:
{vendor_data}

Your task:
1. Write a concise, plain English summary of this vendor (2-3 sentences)
2. Extract searchable keywords that users might use to find this vendor
3. Classify the vendor and extract business entities
4. Suggest typical GL accounts this vendor might be associated with

Respond with ONLY valid JSON in this exact format:
{{
  "summary": "Plain English description of the vendor, their business, and relationship with the company",
  "keywords": ["keyword1", "keyword2", "keyword3", ...],
  "entities": {{
    "vendor_type": "supplier|service_provider|contractor|utility|etc",
    "industry": "brief industry classification",
    "products_services": ["product/service category 1", "category 2"],
    "payment_behavior": "net_30|net_60|cash|etc",
    "typical_expense_categories": ["office supplies", "utilities", "IT services", etc]
  }},
  "relationships": {{
    "typical_gl_accounts": ["5500", "5600"],
    "account_names": ["Office Supplies", "IT & Software"],
    "estimated_monthly_spend": "low|medium|high|very_high",
    "transaction_frequency": "daily|weekly|monthly|quarterly"
  }}
}}

Examples:

Vendor: {{"vendor_name": "Emirates Office Supplies LLC", "payment_terms": "Net 30", "contact_email": "billing@emiratesoffice.ae"}}
Response:
{{
  "summary": "Emirates Office Supplies LLC is a Dubai-based vendor providing office stationery, supplies, and equipment with 30-day payment terms. Primary supplier for day-to-day office consumables.",
  "keywords": ["office supplies", "stationery", "paper", "pens", "folders", "Dubai", "UAE", "office equipment", "supplies"],
  "entities": {{
    "vendor_type": "supplier",
    "industry": "office supplies and equipment",
    "products_services": ["stationery", "office supplies", "paper products", "writing instruments"],
    "payment_behavior": "net_30",
    "typical_expense_categories": ["office supplies", "stationery"]
  }},
  "relationships": {{
    "typical_gl_accounts": ["5500"],
    "account_names": ["Office Supplies"],
    "estimated_monthly_spend": "medium",
    "transaction_frequency": "monthly"
  }}
}}

Vendor: {{"vendor_name": "Dubai Electric", "payment_terms": "Net 15", "contact_email": "commercial@dubaielectric.ae"}}
Response:
{{
  "summary": "Dubai Electric is the utility company providing electricity services with 15-day payment terms. Critical recurring monthly utility expense.",
  "keywords": ["electricity", "utility", "power", "DEWA", "electric", "Dubai", "utilities"],
  "entities": {{
    "vendor_type": "utility",
    "industry": "utilities - electricity",
    "products_services": ["electricity supply", "power"],
    "payment_behavior": "net_15",
    "typical_expense_categories": ["utilities", "electricity"]
  }},
  "relationships": {{
    "typical_gl_accounts": ["5400"],
    "account_names": ["Utilities"],
    "estimated_monthly_spend": "high",
    "transaction_frequency": "monthly"
  }}
}}

Now analyze this vendor and respond with ONLY the JSON structure:
"""

ACCOUNT_CONTEXT_PROMPT = """You are analyzing a GL account in a financial ERP system. Generate intelligent context to help users understand this account's purpose and find it using natural language.

Account Record:
{account_data}

Your task:
1. Explain the account's purpose in plain English (2-3 sentences)
2. Extract searchable keywords
3. Classify the account usage
4. Suggest typical transactions

Respond with ONLY valid JSON in this exact format:
{{
  "summary": "Plain English explanation of account purpose and typical usage",
  "keywords": ["keyword1", "keyword2", ...],
  "entities": {{
    "usage_pattern": "fixed_monthly|variable|occasional|seasonal",
    "typical_transaction_types": ["expense", "payment", "accrual"],
    "materiality": "high|medium|low",
    "financial_statement_category": "operating_expense|cogs|revenue|asset|liability"
  }},
  "relationships": {{
    "common_vendors": [],
    "common_customers": [],
    "parent_account": "account code if hierarchical",
    "related_accounts": ["account codes that often appear in same transactions"]
  }}
}}

Examples:

Account: {{"account_code": "5300", "account_name": "Rent Expense", "account_type": "Expense", "normal_balance": "Debit"}}
Response:
{{
  "summary": "Rent Expense (5300) records monthly office or facility rental payments. Typically a fixed recurring expense posted at the beginning of each month.",
  "keywords": ["rent", "lease", "office rent", "facility rent", "property", "monthly rent", "rental"],
  "entities": {{
    "usage_pattern": "fixed_monthly",
    "typical_transaction_types": ["expense", "payment"],
    "materiality": "high",
    "financial_statement_category": "operating_expense"
  }},
  "relationships": {{
    "common_vendors": [],
    "common_customers": [],
    "parent_account": "5000",
    "related_accounts": ["1000", "2100"]
  }}
}}

Now analyze this account:
"""

JOURNAL_ENTRY_CONTEXT_PROMPT = """You are analyzing a journal entry transaction. Generate context to help users find and understand this transaction using natural language.

Journal Entry:
{entry_data}

Lines:
{lines_data}

Your task:
1. Summarize the business purpose of this transaction (1-2 sentences)
2. Extract searchable keywords
3. Classify the transaction type
4. Identify relationships

Respond with ONLY valid JSON:
{{
  "summary": "Plain English explanation of what this transaction represents",
  "keywords": ["keyword1", "keyword2", ...],
  "entities": {{
    "transaction_nature": "payment|receipt|accrual|adjustment|transfer",
    "business_purpose": "rent_payment|salary|sales|purchase|etc",
    "involves_vendor": true/false,
    "involves_customer": true/false,
    "recurring": true/false
  }},
  "relationships": {{
    "vendor_id": "uuid or null",
    "customer_id": "uuid or null",
    "related_invoice": "invoice number or null",
    "accounts_affected": ["5300", "1000"]
  }}
}}

Now analyze this transaction:
"""


# ============================================
# CONTEXT GENERATION FUNCTIONS
# ============================================

async def generate_vendor_context(vendor_data: Dict[str, Any]) -> Dict[str, Any]:
    """Generate context for a vendor record"""
    if not ai_client:
        raise HTTPException(status_code=503, detail="AI service not available")

    try:
        vendor_json = json.dumps(vendor_data, indent=2)
        prompt = VENDOR_CONTEXT_PROMPT.replace("{vendor_data}", vendor_json)

        logger.info(f"Generating context for vendor: {vendor_data.get('vendor_name', 'Unknown')}")

        response = ai_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1500,
            temperature=0.3,
            messages=[{"role": "user", "content": prompt}]
        )

        response_text = response.content[0].text.strip()

        # Clean markdown if present
        if response_text.startswith("```"):
            response_text = response_text.split("```")[1]
            if response_text.strip().startswith("json"):
                response_text = response_text.strip()[4:]
            response_text = response_text.strip()

        context = json.loads(response_text)

        return {
            "ai_context_summary": context["summary"],
            "ai_context_keywords": context["keywords"],
            "ai_context_entities": context["entities"],
            "ai_context_relationships": context["relationships"],
            "ai_context_model_version": "claude-3.5-sonnet-20241022"
        }

    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse AI response: {e}")
        logger.error(f"Response: {response_text[:500]}")
        raise HTTPException(status_code=500, detail=f"AI response parsing error: {e}")
    except Exception as e:
        logger.error(f"Error generating vendor context: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def generate_account_context(account_data: Dict[str, Any]) -> Dict[str, Any]:
    """Generate context for a GL account"""
    if not ai_client:
        raise HTTPException(status_code=503, detail="AI service not available")

    try:
        account_json = json.dumps(account_data, indent=2)
        prompt = ACCOUNT_CONTEXT_PROMPT.replace("{account_data}", account_json)

        logger.info(f"Generating context for account: {account_data.get('account_code', 'Unknown')}")

        response = ai_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1500,
            temperature=0.3,
            messages=[{"role": "user", "content": prompt}]
        )

        response_text = response.content[0].text.strip()

        if response_text.startswith("```"):
            response_text = response_text.split("```")[1]
            if response_text.strip().startswith("json"):
                response_text = response_text.strip()[4:]
            response_text = response_text.strip()

        context = json.loads(response_text)

        return {
            "ai_context_summary": context["summary"],
            "ai_context_keywords": context["keywords"],
            "ai_context_entities": context["entities"],
            "ai_context_relationships": context["relationships"],
            "ai_context_model_version": "claude-3.5-sonnet-20241022"
        }

    except Exception as e:
        logger.error(f"Error generating account context: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def generate_journal_entry_context(entry_data: Dict[str, Any], lines_data: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Generate context for a journal entry"""
    if not ai_client:
        raise HTTPException(status_code=503, detail="AI service not available")

    try:
        entry_json = json.dumps(entry_data, indent=2)
        lines_json = json.dumps(lines_data, indent=2)
        prompt = JOURNAL_ENTRY_CONTEXT_PROMPT.replace("{entry_data}", entry_json).replace("{lines_data}", lines_json)

        logger.info(f"Generating context for journal entry: {entry_data.get('entry_number', 'Unknown')}")

        response = ai_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1500,
            temperature=0.3,
            messages=[{"role": "user", "content": prompt}]
        )

        response_text = response.content[0].text.strip()

        if response_text.startswith("```"):
            response_text = response_text.split("```")[1]
            if response_text.strip().startswith("json"):
                response_text = response_text.strip()[4:]
            response_text = response_text.strip()

        context = json.loads(response_text)

        return {
            "ai_context_summary": context["summary"],
            "ai_context_keywords": context["keywords"],
            "ai_context_entities": context["entities"],
            "ai_context_relationships": context["relationships"],
            "ai_context_model_version": "claude-3.5-sonnet-20241022"
        }

    except Exception as e:
        logger.error(f"Error generating journal entry context: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# API ENDPOINTS
# ============================================

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "AI Context Generator",
        "ai_enabled": ai_client is not None,
        "database_connected": True  # TODO: actual DB check
    }


@app.post("/generate-context", response_model=ContextResult)
async def generate_context(request: GenerateContextRequest):
    """Generate AI context for a single entity"""

    try:
        # Route to appropriate generator based on entity type
        if request.entity_type == "vendor":
            context = await generate_vendor_context(request.entity_data)
        elif request.entity_type == "account":
            context = await generate_account_context(request.entity_data)
        elif request.entity_type == "journal_entry":
            # Need to fetch journal entry lines
            conn = get_db_connection()
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute("""
                SELECT jel.*, coa.account_code, coa.account_name
                FROM journal_entry_lines jel
                JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
                WHERE jel.entry_id = %s
                ORDER BY jel.line_number
            """, (request.entity_id,))
            lines = cursor.fetchall()
            cursor.close()
            conn.close()
            context = await generate_journal_entry_context(request.entity_data, [dict(line) for line in lines])
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported entity type: {request.entity_type}")

        # Save context to database
        conn = get_db_connection()
        cursor = conn.cursor()

        table_map = {
            "vendor": "vendors",
            "customer": "customers",
            "account": "chart_of_accounts",
            "journal_entry": "journal_entries",
            "ap_invoice": "ap_invoices",
            "ar_invoice": "ar_invoices"
        }

        id_column_map = {
            "vendor": "vendor_id",
            "customer": "customer_id",
            "account": "account_id",
            "journal_entry": "entry_id",
            "ap_invoice": "invoice_id",
            "ar_invoice": "invoice_id"
        }

        table_name = table_map[request.entity_type]
        id_column = id_column_map[request.entity_type]

        cursor.execute(f"""
            UPDATE {table_name}
            SET ai_context_summary = %s,
                ai_context_keywords = %s,
                ai_context_entities = %s,
                ai_context_relationships = %s,
                ai_context_generated_at = NOW(),
                ai_context_model_version = %s
            WHERE {id_column} = %s
        """, (
            context["ai_context_summary"],
            context["ai_context_keywords"],
            json.dumps(context["ai_context_entities"]),
            json.dumps(context["ai_context_relationships"]),
            context["ai_context_model_version"],
            request.entity_id
        ))

        conn.commit()
        cursor.close()
        conn.close()

        logger.info(f"✅ Context saved for {request.entity_type} {request.entity_id}")

        return ContextResult(
            entity_type=request.entity_type,
            entity_id=request.entity_id,
            **context
        )

    except Exception as e:
        logger.error(f"Error in generate_context: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/batch-generate", response_model=BatchGenerateResponse)
async def batch_generate(request: BatchGenerateRequest, background_tasks: BackgroundTasks):
    """Batch generate context for multiple entities"""

    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        table_map = {
            "vendor": ("vendors", "vendor_id"),
            "customer": ("customers", "customer_id"),
            "account": ("chart_of_accounts", "account_id"),
            "journal_entry": ("journal_entries", "entry_id")
        }

        if request.entity_type not in table_map:
            raise HTTPException(status_code=400, detail=f"Unsupported entity type: {request.entity_type}")

        table_name, id_column = table_map[request.entity_type]

        # Fetch records without context
        cursor.execute(f"""
            SELECT *
            FROM {table_name}
            WHERE tenant_id = %s
              AND ai_context_summary IS NULL
            LIMIT %s
        """, (request.tenant_id, request.limit))

        records = cursor.fetchall()
        cursor.close()
        conn.close()

        total = len(records)
        successful = 0
        failed = 0

        logger.info(f"Starting batch context generation for {total} {request.entity_type} records")

        for record in records:
            try:
                # Generate context
                entity_id = str(record[id_column])
                context_request = GenerateContextRequest(
                    entity_type=request.entity_type,
                    entity_id=entity_id,
                    tenant_id=request.tenant_id,
                    entity_data=dict(record)
                )
                await generate_context(context_request)
                successful += 1
            except Exception as e:
                logger.error(f"Failed to generate context for {id_column} {record[id_column]}: {e}")
                failed += 1

        # Calculate coverage
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(f"""
            SELECT
                COUNT(*) as total,
                COUNT(ai_context_summary) as with_context
            FROM {table_name}
            WHERE tenant_id = %s
        """, (request.tenant_id,))
        stats = cursor.fetchone()
        cursor.close()
        conn.close()

        coverage = (stats[1] / stats[0] * 100) if stats[0] > 0 else 0

        logger.info(f"✅ Batch generation complete: {successful} successful, {failed} failed")

        return BatchGenerateResponse(
            entity_type=request.entity_type,
            total_processed=total,
            successful=successful,
            failed=failed,
            coverage_percentage=round(coverage, 2)
        )

    except Exception as e:
        logger.error(f"Error in batch_generate: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/context-stats", response_model=ContextStatsResponse)
async def get_context_stats(tenant_id: str):
    """Get context coverage statistics"""

    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        cursor.execute("""
            SELECT * FROM ai_context_coverage
        """)

        coverage_data = cursor.fetchall()
        cursor.close()
        conn.close()

        total_records = sum(row['total_records'] for row in coverage_data)
        records_with_context = sum(row['records_with_context'] for row in coverage_data)
        overall_coverage = (records_with_context / total_records * 100) if total_records > 0 else 0

        by_entity_type = {}
        for row in coverage_data:
            by_entity_type[row['table_name']] = {
                "total_records": row['total_records'],
                "records_with_context": row['records_with_context'],
                "coverage_percentage": float(row['coverage_percentage']) if row['coverage_percentage'] else 0,
                "last_generated": str(row['last_generated']) if row['last_generated'] else None
            }

        return ContextStatsResponse(
            total_records=total_records,
            records_with_context=records_with_context,
            coverage_percentage=round(overall_coverage, 2),
            by_entity_type=by_entity_type
        )

    except Exception as e:
        logger.error(f"Error getting context stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    print("=" * 60)
    print("AIRP v2.11.0 - AI Context Generator Service")
    print("Intelligent Context Metadata for Natural Language Querying")
    print("=" * 60)
    print(f"API Server: http://localhost:8007")
    print("=" * 60)

    uvicorn.run(app, host="0.0.0.0", port=8007)
