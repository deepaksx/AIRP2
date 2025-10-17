"""
AIRP v2.0 - AI Policy Advisor Service
RAG-based policy guidance for IFRS/GAAP/VAT compliance
"""
import os
import logging
from typing import List, Optional
from datetime import datetime

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field
import anthropic
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="AIRP v2.0 - AI Policy Advisor",
    description="RAG-based policy guidance for financial compliance",
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
query_counter = Counter(
    "airp_ai_policy_queries_total",
    "Total policy queries",
    ["policy_type"],
)

# Initialize AI client
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
AI_PROVIDER = os.getenv("AI_PROVIDER", "anthropic")
QDRANT_HOST = os.getenv("QDRANT_HOST", "localhost")
QDRANT_PORT = int(os.getenv("QDRANT_PORT", "6333"))

if AI_PROVIDER == "anthropic" and ANTHROPIC_API_KEY and len(ANTHROPIC_API_KEY) > 10:
    try:
        ai_client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
        logger.info("Initialized Anthropic Claude client")
    except Exception as e:
        ai_client = None
        logger.warning(f"Failed to initialize Anthropic client: {e} - running in demo mode")
else:
    ai_client = None
    logger.warning("No AI client initialized - running in demo mode")

# Initialize Qdrant client (vector database)
try:
    from qdrant_client import QdrantClient
    qdrant_client = QdrantClient(host=QDRANT_HOST, port=QDRANT_PORT)
    logger.info(f"Connected to Qdrant at {QDRANT_HOST}:{QDRANT_PORT}")
except Exception as e:
    qdrant_client = None
    logger.warning(f"Qdrant connection failed: {e}")

# ============================================
# DATA MODELS
# ============================================

class PolicyQuery(BaseModel):
    tenant_id: str = Field(..., description="Tenant UUID")
    query: str = Field(..., description="Policy question")
    context_type: str = Field(default="general", description="ifrs, gaap, vat, general")
    transaction_data: Optional[dict] = None


class PolicySource(BaseModel):
    source_id: str
    standard: str  # IFRS-15, IAS-16, etc.
    section: str
    content: str
    relevance_score: float


class PolicyResponse(BaseModel):
    query: str
    timestamp: str
    answer: str
    sources: List[PolicySource]
    confidence_score: float
    recommendations: List[str]
    processing_time_ms: float


# ============================================
# KNOWLEDGE BASE (Simplified Demo)
# ============================================

DEMO_KNOWLEDGE_BASE = {
    "ifrs": [
        {
            "id": "IFRS-15-001",
            "standard": "IFRS 15",
            "section": "Revenue Recognition - Performance Obligations",
            "content": "Revenue is recognized when a performance obligation is satisfied by transferring control of a promised good or service to a customer. The amount of revenue recognized is the amount allocated to that performance obligation."
        },
        {
            "id": "IFRS-9-001",
            "standard": "IFRS 9",
            "section": "Financial Instruments - Classification",
            "content": "Financial assets shall be classified based on the entity's business model for managing the financial assets and the contractual cash flow characteristics of the financial asset."
        },
        {
            "id": "IAS-16-001",
            "standard": "IAS 16",
            "section": "Property, Plant and Equipment - Recognition",
            "content": "An item of PPE shall be recognized as an asset when it is probable that future economic benefits will flow to the entity and the cost can be measured reliably."
        },
    ],
    "vat": [
        {
            "id": "UAE-VAT-001",
            "standard": "UAE VAT Law",
            "section": "Standard Rate",
            "content": "The standard VAT rate in the UAE is 5%. VAT is charged on most goods and services supplied in the UAE."
        },
        {
            "id": "UAE-VAT-002",
            "standard": "UAE VAT Law",
            "section": "Zero-Rated Supplies",
            "content": "Zero-rated supplies include exports, international transportation, and supply of investment-grade precious metals."
        },
    ],
}


def search_knowledge_base(query: str, context_type: str) -> List[dict]:
    """
    Simple keyword search in knowledge base
    In production, this would use Qdrant vector search with embeddings
    """
    query_lower = query.lower()
    relevant_docs = []

    knowledge_type = "ifrs" if context_type in ["ifrs", "gaap", "general"] else "vat"
    docs = DEMO_KNOWLEDGE_BASE.get(knowledge_type, [])

    for doc in docs:
        # Simple keyword matching
        content_lower = doc["content"].lower()
        section_lower = doc["section"].lower()

        score = 0
        query_words = query_lower.split()
        for word in query_words:
            if len(word) > 3:  # Skip short words
                if word in content_lower:
                    score += 2
                if word in section_lower:
                    score += 1

        if score > 0:
            relevant_docs.append({
                **doc,
                "relevance_score": min(score / 10, 1.0),
            })

    # Sort by relevance
    relevant_docs.sort(key=lambda x: x["relevance_score"], reverse=True)
    return relevant_docs[:3]  # Top 3


async def generate_policy_answer(query: str, sources: List[dict], transaction_data: Optional[dict]) -> dict:
    """Generate AI-powered policy guidance"""

    if not ai_client:
        # Demo mode - provide basic guidance from knowledge base
        if sources:
            answer = f"Based on the relevant accounting standards:\n\n"
            for i, source in enumerate(sources[:2], 1):
                answer += f"{i}. **{source['standard']} - {source['section']}**\n{source['content']}\n\n"
            answer += "For detailed implementation guidance, please consult with a qualified accountant or refer to the full standards documentation."

            return {
                "answer": answer,
                "confidence_score": 0.7,
                "recommendations": [
                    "Review the full text of the referenced standards",
                    "Consider your specific business context and transactions",
                    "Consult with your auditor for complex scenarios",
                    "Document your accounting policy decisions"
                ],
            }
        else:
            return {
                "answer": "No specific standards found in the knowledge base for this query. This may require professional judgment and consultation with relevant IFRS, GAAP, or VAT regulations.",
                "confidence_score": 0.3,
                "recommendations": ["Consult IFRS/GAAP standards manually", "Seek professional accounting advice"],
            }

    # Build context from sources
    sources_context = "\n\n".join([
        f"[{source['standard']} - {source['section']}]\n{source['content']}"
        for source in sources
    ])

    transaction_context = ""
    if transaction_data:
        transaction_context = f"\nTransaction Details:\n{transaction_data}\n"

    prompt = f"""You are a financial accounting expert specializing in IFRS, GAAP, and UAE VAT regulations.

A user has asked: "{query}"
{transaction_context}
Relevant Standards:
{sources_context if sources_context else "No specific standards found. Use general accounting principles."}

Provide:
1. A clear, accurate answer to the question (2-3 paragraphs)
2. Confidence score (0.0 to 1.0) in your answer
3. Practical recommendations (2-4 bullet points)

Be authoritative but acknowledge when professional judgment is required.
Cite the relevant standards in your answer.

Respond in JSON format:
{{
  "answer": "...",
  "confidence_score": 0.95,
  "recommendations": ["...", "..."]
}}
"""

    try:
        message = ai_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1000,
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

        return result

    except Exception as e:
        logger.error(f"Policy answer generation failed: {str(e)}")
        return {
            "answer": "Unable to generate AI response. Please consult accounting standards directly.",
            "confidence_score": 0.0,
            "recommendations": ["Review relevant IFRS/GAAP standards", "Consult with auditor"],
        }


# ============================================
# API ENDPOINTS
# ============================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "ai-policy-advisor",
        "ai_provider": AI_PROVIDER,
        "ai_available": ai_client is not None,
        "qdrant_available": qdrant_client is not None,
        "timestamp": datetime.utcnow().isoformat(),
    }


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/query", response_model=PolicyResponse)
async def query_policy(request: PolicyQuery):
    """
    Query policy guidance with RAG
    """
    start_time = datetime.utcnow()

    try:
        # Search knowledge base
        relevant_sources = search_knowledge_base(request.query, request.context_type)

        # Generate AI answer
        answer_data = await generate_policy_answer(
            request.query,
            relevant_sources,
            request.transaction_data,
        )

        # Build response
        sources = [
            PolicySource(
                source_id=source["id"],
                standard=source["standard"],
                section=source["section"],
                content=source["content"],
                relevance_score=source["relevance_score"],
            )
            for source in relevant_sources
        ]

        processing_time = (datetime.utcnow() - start_time).total_seconds() * 1000

        query_counter.labels(policy_type=request.context_type).inc()

        return PolicyResponse(
            query=request.query,
            timestamp=datetime.utcnow().isoformat(),
            answer=answer_data["answer"],
            sources=sources,
            confidence_score=answer_data["confidence_score"],
            recommendations=answer_data["recommendations"],
            processing_time_ms=processing_time,
        )

    except Exception as e:
        logger.error(f"Policy query failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Policy query failed: {str(e)}",
        )


@app.get("/standards")
async def list_standards():
    """List available accounting standards in knowledge base"""
    standards = []

    for category, docs in DEMO_KNOWLEDGE_BASE.items():
        for doc in docs:
            if doc["standard"] not in [s["code"] for s in standards]:
                standards.append({
                    "code": doc["standard"],
                    "category": category.upper(),
                    "description": doc["section"],
                })

    return {
        "standards": standards,
        "total_count": len(standards),
    }


# ============================================
# STARTUP
# ============================================

@app.on_event("startup")
async def startup_event():
    logger.info("=" * 60)
    logger.info("AIRP v2.0 - AI Policy Advisor Service")
    logger.info("RAG-based Compliance Guidance (IFRS/GAAP/VAT)")
    logger.info("=" * 60)
    logger.info(f"AI Provider: {AI_PROVIDER}")
    logger.info(f"AI Client Available: {ai_client is not None}")
    logger.info(f"Qdrant Available: {qdrant_client is not None}")
    logger.info(f"Port: {os.getenv('PORT', 8005)}")
    logger.info("=" * 60)


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8005))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=True,
        log_level="info",
    )
