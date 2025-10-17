"""
AIRP v2.0 - AI Bank Reconciliation Service
Autonomous matching of bank transactions with GL entries
"""
import os
import logging
from typing import List, Optional
from datetime import datetime

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel, Field
import anthropic
import httpx
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="AIRP v2.0 - AI Bank Reconciliation",
    description="Autonomous bank transaction matching using AI",
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
reconciliation_counter = Counter(
    "airp_ai_recon_reconciliations_total",
    "Total reconciliations performed",
    ["match_quality"],
)
reconciliation_duration = Histogram(
    "airp_ai_recon_duration_seconds",
    "Reconciliation duration",
)

# Initialize AI client
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
AI_PROVIDER = os.getenv("AI_PROVIDER", "anthropic")

if AI_PROVIDER == "anthropic" and ANTHROPIC_API_KEY and len(ANTHROPIC_API_KEY) > 10:
    try:
        # Create httpx client without proxies to avoid compatibility issues
        http_client = httpx.Client(timeout=60.0)

        # Initialize Anthropic client with custom httpx client
        ai_client = anthropic.Anthropic(
            api_key=ANTHROPIC_API_KEY,
            http_client=http_client,
            max_retries=2
        )
        logger.info("Initialized Anthropic Claude client")
    except Exception as e:
        ai_client = None
        logger.warning(f"Failed to initialize Anthropic client: {e} - running in demo mode")
else:
    ai_client = None
    logger.warning("No AI client initialized - running in demo mode")

# ============================================
# DATA MODELS
# ============================================

class BankTransaction(BaseModel):
    transaction_id: str
    transaction_date: str
    description: str
    amount: float
    transaction_type: str  # debit or credit
    reference_number: Optional[str] = None


class GLTransaction(BaseModel):
    entry_id: str
    entry_date: str
    description: str
    amount: float
    account_code: str
    account_name: str


class ReconciliationRequest(BaseModel):
    tenant_id: str = Field(..., description="Tenant UUID")
    account_id: str = Field(..., description="Bank Account UUID")
    bank_transactions: List[BankTransaction]
    gl_transactions: List[GLTransaction]


class TransactionMatch(BaseModel):
    bank_transaction_id: str
    gl_transaction_id: str
    confidence_score: float = Field(..., ge=0.0, le=1.0)
    match_reasoning: str
    match_type: str  # exact, fuzzy, ai, manual


class ReconciliationResponse(BaseModel):
    account_id: str
    timestamp: str
    matches: List[TransactionMatch]
    unmatched_bank: List[str]
    unmatched_gl: List[str]
    reconciliation_rate: float
    processing_time_ms: float


# ============================================
# RECONCILIATION LOGIC
# ============================================

def exact_match(bank_txn: BankTransaction, gl_txns: List[GLTransaction]) -> Optional[TransactionMatch]:
    """Find exact matches based on amount and date"""
    for gl_txn in gl_txns:
        if (abs(bank_txn.amount - gl_txn.amount) < 0.01 and
            bank_txn.transaction_date == gl_txn.entry_date):
            return TransactionMatch(
                bank_transaction_id=bank_txn.transaction_id,
                gl_transaction_id=gl_txn.entry_id,
                confidence_score=1.0,
                match_reasoning="Exact match on amount and date",
                match_type="exact",
            )
    return None


def fuzzy_match(bank_txn: BankTransaction, gl_txns: List[GLTransaction]) -> Optional[TransactionMatch]:
    """Fuzzy matching based on amount tolerance and date range"""
    best_match = None
    best_score = 0.0

    for gl_txn in gl_txns:
        # Amount similarity (within 1%)
        amount_diff = abs(bank_txn.amount - gl_txn.amount) / max(abs(bank_txn.amount), 0.01)
        amount_score = 1.0 - min(amount_diff, 1.0)

        # Description similarity (simple keyword matching)
        bank_words = set(bank_txn.description.lower().split())
        gl_words = set(gl_txn.description.lower().split())
        common_words = bank_words.intersection(gl_words)
        desc_score = len(common_words) / max(len(bank_words), 1) if bank_words else 0

        # Combined score
        score = (amount_score * 0.7) + (desc_score * 0.3)

        if score > best_score and score > 0.75:
            best_score = score
            best_match = TransactionMatch(
                bank_transaction_id=bank_txn.transaction_id,
                gl_transaction_id=gl_txn.entry_id,
                confidence_score=score,
                match_reasoning=f"Fuzzy match: {int(score*100)}% similarity",
                match_type="fuzzy",
            )

    return best_match


async def ai_match(bank_txn: BankTransaction, gl_txns: List[GLTransaction]) -> Optional[TransactionMatch]:
    """AI-powered matching for complex cases"""
    if not ai_client:
        return None

    gl_context = "\n".join([
        f"- ID: {gl.entry_id}, Date: {gl.entry_date}, Desc: {gl.description}, Amount: {gl.amount}"
        for gl in gl_txns[:10]  # Limit to top 10 candidates
    ])

    prompt = f"""You are a bank reconciliation expert. Match this bank transaction to the most likely GL entry.

Bank Transaction:
- ID: {bank_txn.transaction_id}
- Date: {bank_txn.transaction_date}
- Description: {bank_txn.description}
- Amount: {bank_txn.amount}

Candidate GL Entries:
{gl_context}

If there's a confident match, respond in this exact JSON format:
{{
  "matched_gl_id": "entry_id",
  "confidence": 0.95,
  "reasoning": "Brief explanation"
}}

If no confident match exists, respond with:
{{
  "matched_gl_id": null,
  "confidence": 0.0,
  "reasoning": "No confident match found"
}}
"""

    try:
        message = ai_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=300,
            temperature=0.1,
            messages=[{"role": "user", "content": prompt}],
        )

        response_text = message.content[0].text.strip()

        # Extract JSON from response
        if "```json" in response_text:
            response_text = response_text.split("```json")[1].split("```")[0].strip()
        elif "```" in response_text:
            response_text = response_text.split("```")[1].split("```")[0].strip()

        import json
        result = json.loads(response_text)

        if result.get("matched_gl_id") and result.get("confidence", 0) >= 0.8:
            return TransactionMatch(
                bank_transaction_id=bank_txn.transaction_id,
                gl_transaction_id=result["matched_gl_id"],
                confidence_score=result["confidence"],
                match_reasoning=f"AI Match: {result['reasoning']}",
                match_type="ai",
            )

    except Exception as e:
        logger.error(f"AI matching failed: {str(e)}")

    return None


async def reconcile_transactions(bank_txns: List[BankTransaction], gl_txns: List[GLTransaction]) -> tuple:
    """Hybrid reconciliation: exact → fuzzy → AI"""
    matches = []
    matched_bank_ids = set()
    matched_gl_ids = set()

    # Stage 1: Exact matches
    for bank_txn in bank_txns:
        available_gl = [gl for gl in gl_txns if gl.entry_id not in matched_gl_ids]
        match = exact_match(bank_txn, available_gl)

        if match:
            matches.append(match)
            matched_bank_ids.add(bank_txn.transaction_id)
            matched_gl_ids.add(match.gl_transaction_id)
            reconciliation_counter.labels(match_quality="exact").inc()

    # Stage 2: Fuzzy matches
    unmatched_bank = [txn for txn in bank_txns if txn.transaction_id not in matched_bank_ids]
    for bank_txn in unmatched_bank:
        available_gl = [gl for gl in gl_txns if gl.entry_id not in matched_gl_ids]
        match = fuzzy_match(bank_txn, available_gl)

        if match:
            matches.append(match)
            matched_bank_ids.add(bank_txn.transaction_id)
            matched_gl_ids.add(match.gl_transaction_id)
            reconciliation_counter.labels(match_quality="fuzzy").inc()

    # Stage 3: AI matches (for remaining unmatched)
    unmatched_bank = [txn for txn in bank_txns if txn.transaction_id not in matched_bank_ids]
    for bank_txn in unmatched_bank:
        available_gl = [gl for gl in gl_txns if gl.entry_id not in matched_gl_ids]
        if available_gl:
            match = await ai_match(bank_txn, available_gl)

            if match:
                matches.append(match)
                matched_bank_ids.add(bank_txn.transaction_id)
                matched_gl_ids.add(match.gl_transaction_id)
                reconciliation_counter.labels(match_quality="ai").inc()

    # Determine unmatched
    unmatched_bank_ids = [txn.transaction_id for txn in bank_txns if txn.transaction_id not in matched_bank_ids]
    unmatched_gl_ids = [txn.entry_id for txn in gl_txns if txn.entry_id not in matched_gl_ids]

    return matches, unmatched_bank_ids, unmatched_gl_ids


# ============================================
# API ENDPOINTS
# ============================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "ai-recon",
        "ai_provider": AI_PROVIDER,
        "ai_available": ai_client is not None,
        "timestamp": datetime.utcnow().isoformat(),
    }


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/reconcile", response_model=ReconciliationResponse)
async def reconcile(request: ReconciliationRequest):
    """
    Reconcile bank transactions with GL entries
    """
    start_time = datetime.utcnow()

    try:
        matches, unmatched_bank, unmatched_gl = await reconcile_transactions(
            request.bank_transactions,
            request.gl_transactions,
        )

        processing_time = (datetime.utcnow() - start_time).total_seconds() * 1000

        reconciliation_rate = (
            len(matches) / len(request.bank_transactions) * 100
            if request.bank_transactions else 0
        )

        return ReconciliationResponse(
            account_id=request.account_id,
            timestamp=datetime.utcnow().isoformat(),
            matches=matches,
            unmatched_bank=unmatched_bank,
            unmatched_gl=unmatched_gl,
            reconciliation_rate=reconciliation_rate,
            processing_time_ms=processing_time,
        )

    except Exception as e:
        logger.error(f"Reconciliation failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Reconciliation failed: {str(e)}",
        )


# ============================================
# STARTUP
# ============================================

@app.on_event("startup")
async def startup_event():
    logger.info("=" * 60)
    logger.info("AIRP v2.0 - AI Bank Reconciliation Service")
    logger.info("Autonomous Transaction Matching")
    logger.info("=" * 60)
    logger.info(f"AI Provider: {AI_PROVIDER}")
    logger.info(f"AI Client Available: {ai_client is not None}")
    logger.info(f"Port: {os.getenv('PORT', 8002)}")
    logger.info("=" * 60)


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8002))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=True,
        log_level="info",
    )
