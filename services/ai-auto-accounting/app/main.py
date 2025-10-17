"""
AIRP v2.0 - AI Auto-Accounting Service
Hybrid LLM + XGBoost for intelligent GL code classification
"""
import os
import logging
from typing import List, Optional
from datetime import datetime

from fastapi import FastAPI, HTTPException, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import anthropic
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="AIRP v2.0 - AI Auto-Accounting",
    description="Intelligent GL code classification using hybrid LLM + ML approach",
    version="2.0.0",
)

# Enable CORS for browser testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins in development
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Prometheus metrics
classification_counter = Counter(
    "airp_ai_accounting_classifications_total",
    "Total GL classifications",
    ["confidence_level", "method"],
)
classification_duration = Histogram(
    "airp_ai_accounting_classification_duration_seconds",
    "Classification duration",
    ["method"],
)
feedback_counter = Counter(
    "airp_ai_accounting_feedback_total",
    "User feedback received",
    ["feedback_type"],
)

# Initialize AI client
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
AI_PROVIDER = os.getenv("AI_PROVIDER", "anthropic")

if AI_PROVIDER == "anthropic" and ANTHROPIC_API_KEY:
    ai_client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
    logger.info("Initialized Anthropic Claude client")
else:
    ai_client = None
    logger.warning("No AI client initialized - running in demo mode")

# ============================================
# DATA MODELS
# ============================================

class InvoiceLine(BaseModel):
    line_number: int
    description: str
    amount: float
    quantity: Optional[float] = 1.0


class ClassificationRequest(BaseModel):
    tenant_id: str = Field(..., description="Tenant UUID")
    invoice_id: str = Field(..., description="Invoice UUID")
    vendor_name: Optional[str] = None
    customer_name: Optional[str] = None
    transaction_type: str = Field(..., description="AP or AR")
    lines: List[InvoiceLine]


class AccountSuggestion(BaseModel):
    account_code: str
    account_name: str
    confidence_score: float = Field(..., ge=0.0, le=1.0)
    reasoning: str
    alternative_accounts: List[dict] = []


class ClassificationResponse(BaseModel):
    invoice_id: str
    timestamp: str
    method: str  # "llm", "ml", "hybrid", "rule"
    suggestions: List[AccountSuggestion]
    processing_time_ms: float


class FeedbackRequest(BaseModel):
    invoice_id: str
    line_number: int
    suggested_account: str
    actual_account: str
    is_correct: bool
    user_id: str
    notes: Optional[str] = None


# ============================================
# CHART OF ACCOUNTS (Simplified Demo)
# ============================================

DEMO_CHART_OF_ACCOUNTS = {
    "5100": {"name": "Cost of Goods Sold", "keywords": ["cogs", "inventory", "goods sold", "materials"]},
    "5200": {"name": "Salaries & Wages", "keywords": ["salary", "wages", "payroll", "employee"]},
    "5300": {"name": "Rent Expense", "keywords": ["rent", "lease", "premises"]},
    "5400": {"name": "Utilities", "keywords": ["electricity", "water", "utilities", "power"]},
    "5500": {"name": "Office Supplies", "keywords": ["stationery", "supplies", "office"]},
    "5600": {"name": "Professional Fees", "keywords": ["legal", "consulting", "professional", "advisory"]},
    "5700": {"name": "Marketing & Advertising", "keywords": ["marketing", "advertising", "promotion", "social media"]},
    "5800": {"name": "Travel & Entertainment", "keywords": ["travel", "hotel", "meals", "entertainment", "flight"]},
    "5900": {"name": "IT & Software", "keywords": ["software", "subscription", "saas", "technology", "it"]},
    "6000": {"name": "Depreciation", "keywords": ["depreciation", "amortization"]},
    "6100": {"name": "Insurance", "keywords": ["insurance", "premium"]},
    "6200": {"name": "Bank Charges", "keywords": ["bank fee", "charge", "banking"]},
    "4000": {"name": "Revenue - Product Sales", "keywords": ["sales", "revenue", "product"]},
    "4100": {"name": "Revenue - Services", "keywords": ["service revenue", "consulting revenue"]},
    "1200": {"name": "Accounts Receivable", "keywords": ["receivable", "customer"]},
    "2100": {"name": "Accounts Payable", "keywords": ["payable", "vendor"]},
}

# ============================================
# CORE CLASSIFICATION LOGIC
# ============================================

def rule_based_classification(description: str) -> Optional[AccountSuggestion]:
    """
    Simple rule-based classifier using keyword matching
    """
    description_lower = description.lower()

    best_match = None
    best_score = 0.0

    for account_code, account_info in DEMO_CHART_OF_ACCOUNTS.items():
        score = sum(1 for keyword in account_info["keywords"] if keyword in description_lower)

        if score > best_score:
            best_score = score
            best_match = (account_code, account_info["name"], score)

    if best_match and best_score > 0:
        confidence = min(best_score / 3.0, 0.85)  # Cap at 85% for rule-based
        return AccountSuggestion(
            account_code=best_match[0],
            account_name=best_match[1],
            confidence_score=confidence,
            reasoning=f"Keyword-based match (score: {best_score})",
        )

    return None


async def llm_classification(
    description: str,
    transaction_type: str,
    vendor_or_customer: Optional[str],
) -> Optional[AccountSuggestion]:
    """
    LLM-based classification using Claude/GPT
    """
    if not ai_client:
        logger.warning("LLM client not available, falling back to rules")
        return None

    # Build chart of accounts context
    coa_context = "\n".join([
        f"- {code}: {info['name']}"
        for code, info in DEMO_CHART_OF_ACCOUNTS.items()
    ])

    prompt = f"""You are an expert financial accountant specializing in IFRS and UAE accounting standards.

Given the following transaction, determine the most appropriate General Ledger (GL) account code.

Transaction Details:
- Type: {transaction_type}
- {"Vendor" if transaction_type == "AP" else "Customer"}: {vendor_or_customer or "Unknown"}
- Description: {description}

Available GL Accounts:
{coa_context}

Instructions:
1. Analyze the transaction description
2. Select the most appropriate GL account code
3. Provide your confidence score (0.0 to 1.0)
4. Explain your reasoning briefly

Respond in this exact JSON format:
{{
  "account_code": "XXXX",
  "account_name": "Account Name",
  "confidence_score": 0.95,
  "reasoning": "Brief explanation"
}}"""

    try:
        message = ai_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=500,
            temperature=0.1,
            messages=[{"role": "user", "content": prompt}],
        )

        response_text = message.content[0].text.strip()

        # Extract JSON from response (handle markdown code blocks)
        if "```json" in response_text:
            response_text = response_text.split("```json")[1].split("```")[0].strip()
        elif "```" in response_text:
            response_text = response_text.split("```")[1].split("```")[0].strip()

        import json
        result = json.loads(response_text)

        return AccountSuggestion(
            account_code=result["account_code"],
            account_name=result["account_name"],
            confidence_score=min(float(result["confidence_score"]), 1.0),
            reasoning=f"LLM Analysis: {result['reasoning']}",
        )

    except Exception as e:
        logger.error(f"LLM classification failed: {str(e)}")
        return None


async def hybrid_classification(
    description: str,
    transaction_type: str,
    vendor_or_customer: Optional[str],
) -> AccountSuggestion:
    """
    Hybrid approach: Try LLM first, fall back to rules
    """
    # Try LLM classification
    llm_result = await llm_classification(description, transaction_type, vendor_or_customer)

    if llm_result and llm_result.confidence_score >= 0.75:
        classification_counter.labels(confidence_level="high", method="llm").inc()
        return llm_result

    # Fall back to rule-based
    rule_result = rule_based_classification(description)

    if rule_result:
        classification_counter.labels(confidence_level="medium", method="rule").inc()
        return rule_result

    # Default fallback
    classification_counter.labels(confidence_level="low", method="default").inc()
    return AccountSuggestion(
        account_code="5500",
        account_name="Office Supplies",
        confidence_score=0.30,
        reasoning="Default classification - manual review required",
    )


# ============================================
# API ENDPOINTS
# ============================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "ai-auto-accounting",
        "ai_provider": AI_PROVIDER,
        "ai_available": ai_client is not None,
        "timestamp": datetime.utcnow().isoformat(),
    }


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/classify", response_model=ClassificationResponse)
async def classify_transaction(request: ClassificationRequest):
    """
    Classify invoice lines and suggest GL account codes
    """
    start_time = datetime.utcnow()

    try:
        suggestions = []

        vendor_or_customer = request.vendor_name or request.customer_name

        for line in request.lines:
            suggestion = await hybrid_classification(
                line.description,
                request.transaction_type,
                vendor_or_customer,
            )
            suggestions.append(suggestion)

        processing_time = (datetime.utcnow() - start_time).total_seconds() * 1000

        return ClassificationResponse(
            invoice_id=request.invoice_id,
            timestamp=datetime.utcnow().isoformat(),
            method="hybrid",
            suggestions=suggestions,
            processing_time_ms=processing_time,
        )

    except Exception as e:
        logger.error(f"Classification failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Classification failed: {str(e)}",
        )


@app.post("/feedback")
async def submit_feedback(feedback: FeedbackRequest):
    """
    Submit user feedback for model training
    """
    try:
        feedback_type = "correct" if feedback.is_correct else "incorrect"
        feedback_counter.labels(feedback_type=feedback_type).inc()

        # In production, this would store in database for retraining
        logger.info(
            f"Feedback received for invoice {feedback.invoice_id}: "
            f"Suggested={feedback.suggested_account}, Actual={feedback.actual_account}, "
            f"Correct={feedback.is_correct}"
        )

        return {
            "status": "success",
            "message": "Feedback recorded for model improvement",
            "invoice_id": feedback.invoice_id,
        }

    except Exception as e:
        logger.error(f"Feedback submission failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Feedback submission failed: {str(e)}",
        )


@app.get("/accounts")
async def get_chart_of_accounts():
    """
    Get available GL account codes
    """
    return {
        "accounts": [
            {"code": code, "name": info["name"]}
            for code, info in DEMO_CHART_OF_ACCOUNTS.items()
        ]
    }


# ============================================
# STARTUP
# ============================================

@app.on_event("startup")
async def startup_event():
    logger.info("=" * 60)
    logger.info("AIRP v2.0 - AI Auto-Accounting Service")
    logger.info("AI-Native Financial ERP")
    logger.info("=" * 60)
    logger.info(f"AI Provider: {AI_PROVIDER}")
    logger.info(f"AI Client Available: {ai_client is not None}")
    logger.info(f"Port: {os.getenv('PORT', 8001)}")
    logger.info("=" * 60)


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8001))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=True,
        log_level="info",
    )
