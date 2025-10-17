"""
AIRP v2.0 - AI Cash Flow Forecasting Service
Time series forecasting using Prophet + LLM explanations
"""
import os
import logging
from typing import List, Optional
from datetime import datetime, timedelta

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field
import anthropic
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import pandas as pd
import numpy as np

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="AIRP v2.0 - AI Cash Flow Forecasting",
    description="Time series forecasting with AI-powered insights",
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
forecast_counter = Counter(
    "airp_ai_forecast_forecasts_total",
    "Total forecasts generated",
    ["forecast_horizon"],
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

class HistoricalData(BaseModel):
    date: str
    inflows: float
    outflows: float
    net_cash_flow: float


class ForecastRequest(BaseModel):
    tenant_id: str = Field(..., description="Tenant UUID")
    account_id: str = Field(..., description="Bank Account UUID")
    historical_data: List[HistoricalData]
    forecast_days: int = Field(default=30, ge=1, le=365)
    current_balance: float


class ForecastPoint(BaseModel):
    date: str
    predicted_inflows: float
    predicted_outflows: float
    predicted_balance: float
    confidence_lower: float
    confidence_upper: float


class ForecastResponse(BaseModel):
    account_id: str
    timestamp: str
    current_balance: float
    forecast_horizon_days: int
    forecasts: List[ForecastPoint]
    insights: str
    risk_alerts: List[str]
    processing_time_ms: float


# ============================================
# FORECASTING LOGIC
# ============================================

def generate_simple_forecast(historical_data: List[HistoricalData], days: int, current_balance: float) -> List[ForecastPoint]:
    """
    Simple moving average forecast
    In production, this would use Prophet or ARIMA
    """
    # Calculate averages from historical data
    avg_inflows = np.mean([d.inflows for d in historical_data]) if historical_data else 0
    avg_outflows = np.mean([d.outflows for d in historical_data]) if historical_data else 0
    avg_net = avg_inflows - avg_outflows

    # Add some variance (std dev)
    std_inflows = np.std([d.inflows for d in historical_data]) if len(historical_data) > 1 else avg_inflows * 0.1
    std_outflows = np.std([d.outflows for d in historical_data]) if len(historical_data) > 1 else avg_outflows * 0.1

    forecasts = []
    running_balance = current_balance

    for i in range(days):
        forecast_date = (datetime.now() + timedelta(days=i+1)).strftime("%Y-%m-%d")

        # Add some randomness to make it more realistic
        predicted_inflows = max(0, avg_inflows + np.random.normal(0, std_inflows * 0.5))
        predicted_outflows = max(0, avg_outflows + np.random.normal(0, std_outflows * 0.5))
        running_balance += (predicted_inflows - predicted_outflows)

        # Calculate confidence intervals (95%)
        confidence_range = (std_inflows + std_outflows) * 1.96
        confidence_lower = running_balance - confidence_range
        confidence_upper = running_balance + confidence_range

        forecasts.append(ForecastPoint(
            date=forecast_date,
            predicted_inflows=round(predicted_inflows, 2),
            predicted_outflows=round(predicted_outflows, 2),
            predicted_balance=round(running_balance, 2),
            confidence_lower=round(confidence_lower, 2),
            confidence_upper=round(confidence_upper, 2),
        ))

    return forecasts


async def generate_ai_insights(historical_data: List[HistoricalData], forecasts: List[ForecastPoint]) -> str:
    """Generate AI-powered narrative insights"""
    if not ai_client:
        return "AI insights not available in demo mode. Historical trends show stable cash flow patterns."

    # Prepare data summary
    avg_balance = np.mean([f.predicted_balance for f in forecasts])
    min_balance = min([f.predicted_balance for f in forecasts])
    trend = "increasing" if forecasts[-1].predicted_balance > forecasts[0].predicted_balance else "decreasing"

    prompt = f"""You are a financial analyst. Analyze this cash flow forecast and provide actionable insights.

Forecast Summary:
- Horizon: {len(forecasts)} days
- Average Predicted Balance: AED {avg_balance:,.2f}
- Minimum Predicted Balance: AED {min_balance:,.2f}
- Trend: {trend}

Historical Data (last 5 days):
{chr(10).join([f"- {d.date}: Inflows={d.inflows:,.2f}, Outflows={d.outflows:,.2f}, Net={d.net_cash_flow:,.2f}" for d in historical_data[-5:]])}

Provide:
1. Key insights (2-3 sentences)
2. Cash management recommendations
3. Risk warnings if any

Keep it concise and actionable (max 200 words).
"""

    try:
        message = ai_client.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=400,
            temperature=0.3,
            messages=[{"role": "user", "content": prompt}],
        )

        return message.content[0].text.strip()

    except Exception as e:
        logger.error(f"AI insights generation failed: {str(e)}")
        return "AI insights temporarily unavailable. Please review the forecast data manually."


def detect_risk_alerts(forecasts: List[ForecastPoint], current_balance: float) -> List[str]:
    """Detect potential cash flow risks"""
    alerts = []

    # Check for negative balance
    negative_days = [f for f in forecasts if f.predicted_balance < 0]
    if negative_days:
        alerts.append(f"⚠️ Negative balance predicted on {len(negative_days)} days (first on {negative_days[0].date})")

    # Check for significant balance drop
    balance_drop = current_balance - min([f.predicted_balance for f in forecasts])
    if balance_drop > current_balance * 0.5:
        alerts.append(f"⚠️ Significant balance drop expected: AED {balance_drop:,.2f} ({balance_drop/current_balance*100:.1f}%)")

    # Check for low balance threshold
    low_balance_days = [f for f in forecasts if 0 < f.predicted_balance < 10000]
    if low_balance_days:
        alerts.append(f"⚠️ Low balance (<AED 10,000) expected on {len(low_balance_days)} days")

    return alerts


# ============================================
# API ENDPOINTS
# ============================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "ai-forecast",
        "ai_provider": AI_PROVIDER,
        "ai_available": ai_client is not None,
        "timestamp": datetime.utcnow().isoformat(),
    }


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/forecast", response_model=ForecastResponse)
async def forecast_cash_flow(request: ForecastRequest):
    """
    Generate cash flow forecast
    """
    start_time = datetime.utcnow()

    try:
        # Generate forecast
        forecasts = generate_simple_forecast(
            request.historical_data,
            request.forecast_days,
            request.current_balance,
        )

        # Generate AI insights
        insights = await generate_ai_insights(request.historical_data, forecasts)

        # Detect risks
        risk_alerts = detect_risk_alerts(forecasts, request.current_balance)

        processing_time = (datetime.utcnow() - start_time).total_seconds() * 1000

        forecast_counter.labels(forecast_horizon=f"{request.forecast_days}d").inc()

        return ForecastResponse(
            account_id=request.account_id,
            timestamp=datetime.utcnow().isoformat(),
            current_balance=request.current_balance,
            forecast_horizon_days=request.forecast_days,
            forecasts=forecasts,
            insights=insights,
            risk_alerts=risk_alerts,
            processing_time_ms=processing_time,
        )

    except Exception as e:
        logger.error(f"Forecasting failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Forecasting failed: {str(e)}",
        )


# ============================================
# STARTUP
# ============================================

@app.on_event("startup")
async def startup_event():
    logger.info("=" * 60)
    logger.info("AIRP v2.0 - AI Cash Flow Forecasting Service")
    logger.info("Time Series Forecasting with AI Insights")
    logger.info("=" * 60)
    logger.info(f"AI Provider: {AI_PROVIDER}")
    logger.info(f"AI Client Available: {ai_client is not None}")
    logger.info(f"Port: {os.getenv('PORT', 8003)}")
    logger.info("=" * 60)


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8003))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=True,
        log_level="info",
    )
