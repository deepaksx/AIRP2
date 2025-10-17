"""
AIRP v2.0 - AI Narrative Reporting Service
Generate executive summaries and management commentary from financial data
"""
import os
import logging
from typing import List, Optional, Dict
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
    title="AIRP v2.0 - AI Narrative Reporting",
    description="Auto-generate executive summaries and financial commentary",
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
narrative_counter = Counter(
    "airp_ai_narrative_reports_total",
    "Total narrative reports generated",
    ["report_type"],
)

# Initialize AI client
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
AI_PROVIDER = os.getenv("AI_PROVIDER", "anthropic")

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

# ============================================
# DATA MODELS
# ============================================

class FinancialMetrics(BaseModel):
    revenue: float
    expenses: float
    net_income: float
    cash_balance: float
    accounts_receivable: float
    accounts_payable: float
    budget_variance: Optional[float] = None


class NarrativeRequest(BaseModel):
    tenant_id: str = Field(..., description="Tenant UUID")
    report_type: str = Field(..., description="monthly, quarterly, annual, custom")
    period_start: str
    period_end: str
    current_period: FinancialMetrics
    previous_period: Optional[FinancialMetrics] = None
    budget: Optional[FinancialMetrics] = None
    key_events: Optional[List[str]] = []


class NarrativeResponse(BaseModel):
    tenant_id: str
    report_type: str
    timestamp: str
    executive_summary: str
    performance_analysis: str
    variance_commentary: str
    key_insights: List[str]
    recommendations: List[str]
    processing_time_ms: float


# ============================================
# NARRATIVE GENERATION LOGIC
# ============================================

async def generate_narrative(request: NarrativeRequest) -> Dict[str, any]:
    """Generate AI-powered narrative report"""

    if not ai_client:
        # Demo mode - generate basic narrative from template
        profit_margin = (request.current_period.net_income / request.current_period.revenue * 100
                        if request.current_period.revenue > 0 else 0)

        revenue_growth = 0
        if request.previous_period:
            revenue_growth = ((request.current_period.revenue - request.previous_period.revenue) /
                             request.previous_period.revenue * 100)

        exec_summary = f"The organization achieved revenue of AED {request.current_period.revenue:,.0f} "
        exec_summary += f"with a net income of AED {request.current_period.net_income:,.0f}, "
        exec_summary += f"representing a {profit_margin:.1f}% profit margin. "
        if revenue_growth > 0:
            exec_summary += f"This reflects a {revenue_growth:.1f}% growth compared to the previous period. "
        exec_summary += f"Cash position stands at AED {request.current_period.cash_balance:,.0f}."

        performance = f"Revenue performance for the period was AED {request.current_period.revenue:,.0f}, "
        performance += f"with total expenses of AED {request.current_period.expenses:,.0f}. "
        performance += f"The profit margin of {profit_margin:.1f}% indicates {'strong' if profit_margin > 15 else 'moderate' if profit_margin > 5 else 'challenging'} profitability. "
        performance += f"\n\nWorking capital metrics show accounts receivable at AED {request.current_period.accounts_receivable:,.0f} "
        performance += f"and accounts payable at AED {request.current_period.accounts_payable:,.0f}. "
        performance += f"The cash balance of AED {request.current_period.cash_balance:,.0f} provides adequate liquidity for operations."

        variance_text = "Financial performance aligns with operational expectations. "
        if request.budget:
            budget_var = ((request.current_period.revenue - request.budget.revenue) / request.budget.revenue * 100)
            variance_text += f"Compared to budget, revenue variance is {budget_var:+.1f}%, "
            variance_text += "which is within acceptable parameters. " if abs(budget_var) < 10 else "requiring management attention. "

        insights = [
            f"Profit margin of {profit_margin:.1f}% indicates {'healthy' if profit_margin > 10 else 'moderate'} operational efficiency",
            f"Cash position is {'strong' if request.current_period.cash_balance > request.current_period.expenses else 'adequate'} at AED {request.current_period.cash_balance:,.0f}",
            f"Revenue trend is {'' if revenue_growth >= 0 else 'declining and requires attention'}"
        ]

        if request.previous_period and revenue_growth > 0:
            insights.append(f"Period-over-period growth of {revenue_growth:.1f}% demonstrates positive momentum")

        recommendations = [
            "Monitor cash flow closely to maintain adequate working capital",
            "Review expense categories for optimization opportunities",
            "Consider strategic investments to sustain growth trajectory"
        ]

        if profit_margin < 10:
            recommendations.append("Focus on margin improvement initiatives")

        return {
            "executive_summary": exec_summary,
            "performance_analysis": performance,
            "variance_commentary": variance_text,
            "key_insights": insights,
            "recommendations": recommendations,
        }

    # Calculate metrics
    revenue_growth = 0
    if request.previous_period:
        revenue_growth = ((request.current_period.revenue - request.previous_period.revenue) /
                         request.previous_period.revenue * 100)

    profit_margin = (request.current_period.net_income / request.current_period.revenue * 100
                    if request.current_period.revenue > 0 else 0)

    # Build context for LLM
    context = f"""
Financial Period: {request.period_start} to {request.period_end}

Current Period Metrics:
- Revenue: AED {request.current_period.revenue:,.2f}
- Expenses: AED {request.current_period.expenses:,.2f}
- Net Income: AED {request.current_period.net_income:,.2f}
- Cash Balance: AED {request.current_period.cash_balance:,.2f}
- A/R: AED {request.current_period.accounts_receivable:,.2f}
- A/P: AED {request.current_period.accounts_payable:,.2f}

"""

    if request.previous_period:
        context += f"""
Previous Period Metrics:
- Revenue: AED {request.previous_period.revenue:,.2f}
- Net Income: AED {request.previous_period.net_income:,.2f}
- Revenue Growth: {revenue_growth:.1f}%

"""

    if request.budget:
        budget_variance = request.current_period.revenue - request.budget.revenue
        context += f"""
Budget Comparison:
- Budgeted Revenue: AED {request.budget.revenue:,.2f}
- Actual Revenue: AED {request.current_period.revenue:,.2f}
- Variance: AED {budget_variance:,.2f} ({budget_variance/request.budget.revenue*100:.1f}%)
"""

    if request.key_events:
        context += f"\nKey Events:\n" + "\n".join([f"- {event}" for event in request.key_events])

    prompt = f"""You are a CFO writing a financial report for a board meeting. Analyze this data and provide:

{context}

Generate a professional financial narrative with these sections:

1. EXECUTIVE SUMMARY (3-4 sentences)
   - High-level overview of financial performance
   - Key achievements and challenges

2. PERFORMANCE ANALYSIS (2-3 paragraphs)
   - Detailed revenue and profitability analysis
   - Trends and comparisons
   - Working capital commentary

3. VARIANCE COMMENTARY (1-2 paragraphs)
   - Explanation of significant variances (if any)
   - Budget vs actual analysis

4. KEY INSIGHTS (3-5 bullet points)
   - Critical observations
   - Risk factors
   - Opportunities

5. RECOMMENDATIONS (3-5 bullet points)
   - Actionable next steps
   - Strategic recommendations

Use professional financial language. Be concise but insightful. Focus on actionable intelligence.
Respond in JSON format:
{{
  "executive_summary": "...",
  "performance_analysis": "...",
  "variance_commentary": "...",
  "key_insights": ["...", "..."],
  "recommendations": ["...", "..."]
}}
"""

    try:
        message = ai_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=2000,
            temperature=0.3,
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
        logger.error(f"Narrative generation failed: {str(e)}")
        return {
            "executive_summary": "Error generating narrative. Please review data manually.",
            "performance_analysis": "AI service temporarily unavailable.",
            "variance_commentary": "Manual review required.",
            "key_insights": ["AI generation failed"],
            "recommendations": ["Retry later or review manually"],
        }


# ============================================
# API ENDPOINTS
# ============================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "ai-narrative",
        "ai_provider": AI_PROVIDER,
        "ai_available": ai_client is not None,
        "timestamp": datetime.utcnow().isoformat(),
    }


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/generate", response_model=NarrativeResponse)
async def generate_report(request: NarrativeRequest):
    """
    Generate narrative financial report
    """
    start_time = datetime.utcnow()

    try:
        narrative = await generate_narrative(request)

        processing_time = (datetime.utcnow() - start_time).total_seconds() * 1000

        narrative_counter.labels(report_type=request.report_type).inc()

        return NarrativeResponse(
            tenant_id=request.tenant_id,
            report_type=request.report_type,
            timestamp=datetime.utcnow().isoformat(),
            executive_summary=narrative["executive_summary"],
            performance_analysis=narrative["performance_analysis"],
            variance_commentary=narrative["variance_commentary"],
            key_insights=narrative["key_insights"],
            recommendations=narrative["recommendations"],
            processing_time_ms=processing_time,
        )

    except Exception as e:
        logger.error(f"Report generation failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Report generation failed: {str(e)}",
        )


# ============================================
# STARTUP
# ============================================

@app.on_event("startup")
async def startup_event():
    logger.info("=" * 60)
    logger.info("AIRP v2.0 - AI Narrative Reporting Service")
    logger.info("Executive Summaries & Management Commentary")
    logger.info("=" * 60)
    logger.info(f"AI Provider: {AI_PROVIDER}")
    logger.info(f"AI Client Available: {ai_client is not None}")
    logger.info(f"Port: {os.getenv('PORT', 8004)}")
    logger.info("=" * 60)


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8004))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=True,
        log_level="info",
    )
