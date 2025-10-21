# AIRP v2.10.1 - AI Services User Manual

**Version**: 2.10.1
**Document Date**: October 20, 2025
**Target Audience**: End Users, Accountants, Finance Professionals

---

## Table of Contents

1. [Introduction](#introduction)
2. [AI Auto-Accounting (Transaction Classification)](#1-ai-auto-accounting-transaction-classification)
3. [AI Bank Reconciliation](#2-ai-bank-reconciliation)
4. [AI Cash Flow Forecasting](#3-ai-cash-flow-forecasting)
5. [AI Report Narrative Generation](#4-ai-report-narrative-generation)
6. [AI Policy Advisor](#5-ai-policy-advisor)
7. [ChatERP (Natural Language Query)](#6-chaterp-natural-language-query)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

---

## Introduction

AIRP v2.10.1 includes **6 AI-powered microservices** designed to automate and enhance financial operations. This manual provides step-by-step instructions for using each AI service through the web interface.

### What Can AI Do for You?

- **Classify transactions** automatically to the correct GL accounts
- **Match bank transactions** with accounting records
- **Forecast cash flow** using historical data
- **Generate narrative explanations** for financial reports
- **Answer policy questions** using your company's financial policies
- **Query your data** using natural language (no SQL required)

### Accessing AI Services

All AI features are accessible from:
- **Main Dashboard**: http://localhost:5000/index.html
- **Direct Demo Pages**: http://localhost:5000/[demo-name].html

---

## 1. AI Auto-Accounting (Transaction Classification)

**Purpose**: Automatically classify transactions to the correct GL account based on description, amount, and vendor.

**Service**: AI Classification Service (Port 8001)
**Demo Page**: http://localhost:5000/classify-demo.html

### How to Use

#### Step 1: Access the Classification Demo
1. Open your browser and navigate to: http://localhost:5000/classify-demo.html
2. You'll see a form with three input fields

#### Step 2: Enter Transaction Details
Fill in the following information:

**Transaction Description** (Required)
- Enter a natural language description of the transaction
- Examples:
  - "Office supplies purchase from Staples"
  - "Monthly rent payment"
  - "Laptop purchased for employee"
  - "Consulting fees from ABC Consulting"

**Amount** (Optional but recommended)
- Enter the transaction amount in AED
- Examples: 150.50, 5000, 12345.67

**Vendor Name** (Optional but recommended)
- Enter the vendor/supplier name
- Examples: "Staples Inc", "Dubai Electric", "Emirates NBD"

#### Step 3: Click "Classify Transaction"
The AI will analyze your input and return:

**Response Fields**:
- **Account Code**: Recommended GL account (e.g., "5500" for Office Supplies)
- **Account Name**: Full account name (e.g., "Office Supplies Expense")
- **Confidence Score**: 0.0 to 1.0 (higher is better)
- **Reasoning**: AI explanation for why this account was chosen

#### Step 4: Review and Use Results

**High Confidence (0.8 - 1.0)**: ✅ Safe to auto-post
```
Account: 5500 - Office Supplies
Confidence: 0.95
Reasoning: "Office supplies" keyword detected, amount consistent with typical purchases
```

**Medium Confidence (0.5 - 0.79)**: ⚠️ Review before posting
```
Account: 5100 - COGS
Confidence: 0.65
Reasoning: Ambiguous description, recommend manual review
```

**Low Confidence (< 0.5)**: ❌ Requires manual classification
```
Account: 5900 - Miscellaneous
Confidence: 0.35
Reasoning: Unable to determine account from description
```

### Real-World Example

**Scenario**: You receive an invoice from Staples for office supplies

**Input**:
- Description: "Paper, pens, and folders from Staples"
- Amount: 275.50
- Vendor: "Staples Office Supplies"

**AI Response**:
```json
{
  "account_code": "5500",
  "account_name": "Office Supplies",
  "confidence": 0.92,
  "reasoning": "Keywords 'paper', 'pens', 'folders' match Office Supplies category. Vendor 'Staples' is known office supplier. Amount is typical for office supply purchases."
}
```

**Action**: ✅ Use this classification - confidence is high (0.92)

### Use Cases

1. **Bulk Invoice Processing**: Classify 100+ invoices in minutes
2. **Expense Report Review**: Auto-classify employee expenses
3. **Bank Statement Import**: Classify downloaded transactions
4. **Training Data**: Build ML model by reviewing AI suggestions

### Tips for Better Results

✅ **Do**:
- Provide detailed descriptions (not just "Payment")
- Include vendor name when available
- Use consistent terminology
- Review AI suggestions before posting

❌ **Don't**:
- Enter vague descriptions ("Misc expense")
- Mix multiple transactions in one description
- Ignore low confidence scores
- Auto-post without review for new vendors

---

## 2. AI Bank Reconciliation

**Purpose**: Match bank transactions with accounting records automatically.

**Service**: AI Reconciliation Service (Port 8002)
**Demo Page**: http://localhost:5000/recon-demo.html

### How to Use

#### Step 1: Access the Reconciliation Demo
1. Navigate to: http://localhost:5000/recon-demo.html
2. You'll see two input sections: Bank Transactions and GL Transactions

#### Step 2: Upload/Enter Bank Transactions
You can either:
- **Upload CSV**: Click "Upload Bank Statement" and select your CSV file
- **Manual Entry**: Fill in the form with transaction details

**Bank Transaction Fields**:
- **Date**: Transaction date (YYYY-MM-DD)
- **Description**: Bank description (as shown in statement)
- **Amount**: Transaction amount (positive for deposits, negative for withdrawals)
- **Reference**: Bank reference number (optional)

**Example Bank Transaction**:
```
Date: 2025-10-15
Description: WIRE TFR FROM ABC CORP
Amount: 5000.00
Reference: BNK20251015001
```

#### Step 3: System Fetches GL Transactions
The AI automatically retrieves unreconciled GL transactions from your accounting system for the same period.

#### Step 4: Click "Run AI Reconciliation"
The AI will:
1. Analyze bank transactions
2. Compare with GL transactions
3. Apply fuzzy matching algorithms
4. Score potential matches

#### Step 5: Review Matches

**Match Types**:

**Exact Match (100% confidence)** ✅
```
Bank: WIRE TFR FROM ABC CORP | 5000.00 | Oct 15
GL:   Invoice ABC-001         | 5000.00 | Oct 15
Match Score: 1.00 (Exact date, exact amount, vendor match)
```

**Fuzzy Match (70-99% confidence)** ⚠️
```
Bank: PMT - EMIRATES ELECTRIC | 450.23 | Oct 18
GL:   Electricity Bill Sep    | 450.23 | Oct 17
Match Score: 0.85 (Amount match, date within 2 days, description similar)
```

**No Match (< 70% confidence)** ❌
```
Bank: ATM WITHDRAWAL | 200.00 | Oct 20
GL:   [No matches found]
Match Score: 0.00
Suggestion: Create manual journal entry
```

#### Step 6: Accept or Reject Matches

For each suggested match:
- **Accept**: Click ✅ to confirm reconciliation
- **Reject**: Click ❌ to decline and investigate manually
- **Flag**: Click 🚩 to mark for supervisor review

#### Step 7: Post Reconciliation
Once you accept matches, click "Post Reconciliation" to:
- Update GL entries with bank reference
- Mark transactions as reconciled
- Generate reconciliation report

### Matching Rules

The AI uses these criteria:

| Criteria | Weight | Example |
|----------|--------|---------|
| Exact amount match | 40% | Bank: 5000.00 = GL: 5000.00 |
| Date proximity | 25% | Within 3 days = high score |
| Description similarity | 20% | "ABC Corp" matches "ABC Corporation" |
| Vendor/customer match | 15% | Vendor name detected in bank desc |

### Real-World Example

**Scenario**: You have 50 bank transactions to reconcile from last month

**Process**:
1. Export bank statement as CSV (from bank website)
2. Upload to recon-demo.html
3. Click "Run AI Reconciliation"
4. AI matches 42/50 transactions automatically (84% match rate)
5. Review 8 unmatched transactions manually
6. Accept all matches and post reconciliation

**Time Saved**: Manual reconciliation (2 hours) → AI-assisted (20 minutes)

### Use Cases

1. **Monthly Bank Reconciliation**: Automate end-of-month close
2. **Credit Card Reconciliation**: Match corporate card transactions
3. **Multi-Currency Accounts**: Reconcile foreign currency bank accounts
4. **High-Volume Accounts**: Process 1000+ transactions efficiently

### Tips for Better Reconciliation

✅ **Do**:
- Upload complete bank statements (not partial)
- Use consistent date formats (YYYY-MM-DD)
- Review fuzzy matches carefully (70-99% confidence)
- Investigate unmatched items immediately

❌ **Don't**:
- Mix multiple bank accounts in one upload
- Auto-accept matches below 85% confidence
- Ignore timing differences (>5 days)
- Skip manual review for large amounts (>10,000 AED)

---

## 3. AI Cash Flow Forecasting

**Purpose**: Predict future cash positions using historical data and machine learning.

**Service**: AI Forecasting Service (Port 8003)
**Demo Page**: http://localhost:5000/cashflow-demo.html

### How to Use

#### Step 1: Access the Forecasting Demo
1. Navigate to: http://localhost:5000/cashflow-demo.html
2. You'll see options to select forecast period and parameters

#### Step 2: Select Forecast Parameters

**Date Range for Historical Data**:
- Select start date (minimum: 3 months of history recommended)
- Select end date (today or recent date)
- Example: Jan 1, 2025 to Oct 20, 2025

**Forecast Horizon**:
- Select number of periods to forecast
- Options: 1 week, 1 month, 3 months, 6 months, 1 year
- Recommendation: Start with 3 months for best accuracy

**Forecast Granularity**:
- Daily: For short-term cash management (1-4 weeks)
- Weekly: For operational planning (1-3 months)
- Monthly: For strategic planning (3-12 months)

#### Step 3: Click "Generate Forecast"
The AI will:
1. Fetch historical cash flow data from GL account 1000 (Cash)
2. Apply Prophet time-series forecasting algorithm
3. Detect seasonal patterns and trends
4. Generate predictions with confidence intervals

#### Step 4: Review Forecast Results

**Forecast Chart**:
```
Cash Balance Forecast (Next 3 Months)

AED 150,000 |                    ╱‾‾‾╲
            |                  ╱      ╲
AED 100,000 |    ‾‾‾╲        ╱          ╲
            |         ╲    ╱              ╲
AED  50,000 |          ╲╱                  ╲___
            |
            └─────────────────────────────────────
             Oct      Nov       Dec       Jan

Legend:
━━━ Predicted cash balance
┄┄┄ Lower bound (80% confidence)
┄┄┄ Upper bound (80% confidence)
```

**Forecast Table**:
| Date | Predicted Balance | Lower Bound | Upper Bound | Confidence |
|------|-------------------|-------------|-------------|------------|
| Nov 1 | 125,450 AED | 110,000 AED | 140,000 AED | 85% |
| Nov 15 | 118,230 AED | 105,000 AED | 132,000 AED | 82% |
| Dec 1 | 135,670 AED | 120,000 AED | 150,000 AED | 80% |

#### Step 5: Analyze Trends

**Seasonal Patterns Detected**:
```
Monthly Pattern:
- Beginning of month: +15% (salary payments received)
- Mid-month: -10% (vendor payment cycle)
- End of month: +5% (collections from customers)

Weekly Pattern:
- Monday-Tuesday: Stable
- Wednesday-Friday: Increased activity
- Weekend: Minimal changes
```

**Trend Analysis**:
```
Overall Trend: ↗️ Increasing
Growth Rate: +2.5% per month
Volatility: Medium (±8% standard deviation)
```

#### Step 6: Use Forecast for Planning

**Alerts Generated**:
- ⚠️ **Low Cash Alert**: Nov 15 - Predicted balance below 100,000 AED threshold
- ✅ **Positive Cash**: Dec 1 - Predicted surplus of 35,000 AED
- 🚨 **Cash Shortage Risk**: 15% probability of falling below 50,000 AED in November

**Recommended Actions**:
1. Accelerate collections before Nov 15
2. Delay non-critical payments to mid-December
3. Arrange 50,000 AED credit line as safety buffer

### Real-World Example

**Scenario**: CFO needs to plan cash requirements for Q4 2025

**Process**:
1. Select historical data: Jan 1 - Sep 30, 2025 (9 months)
2. Select forecast period: Oct 1 - Dec 31, 2025 (3 months)
3. Granularity: Weekly
4. Generate forecast

**Results**:
```
Week 1 Oct: 145,000 AED ✅ Comfortable
Week 2 Oct: 132,000 AED ✅ Comfortable
Week 3 Oct: 118,000 AED ⚠️ Watch closely
Week 4 Oct: 95,000 AED 🚨 Below threshold (100K)
Week 1 Nov: 88,000 AED 🚨 Critical - Action needed
```

**Decision**: CFO accelerates 30,000 AED receivables collection in Week 3 to avoid Week 4 shortage.

### Forecasting Models Used

**Prophet Algorithm**:
- Developed by Facebook (Meta)
- Handles seasonality, holidays, trend changes
- Robust to missing data and outliers
- Provides confidence intervals

**Input Features**:
- Historical cash balances (GL account 1000)
- Transaction volumes and patterns
- Day of week effects
- Month of year seasonality
- Holiday calendar (UAE public holidays)

### Use Cases

1. **Working Capital Management**: Plan short-term cash needs
2. **Credit Line Planning**: Determine when to draw on credit facilities
3. **Investment Decisions**: Identify surplus cash for investment
4. **Scenario Planning**: What-if analysis for business decisions
5. **Budget vs Actual**: Compare forecasts to actual results

### Tips for Accurate Forecasting

✅ **Do**:
- Use at least 6 months of historical data (12+ months is better)
- Update forecasts weekly or monthly
- Review and adjust based on actual results
- Consider external factors (seasonality, economic conditions)
- Set realistic confidence thresholds (80-90%)

❌ **Don't**:
- Rely on forecasts with <3 months of history
- Ignore confidence intervals (always check upper/lower bounds)
- Forget to account for one-time events (large purchases, tax payments)
- Use daily granularity for long-term forecasts (too noisy)
- Trust forecasts beyond 6 months without frequent updates

---

## 4. AI Report Narrative Generation

**Purpose**: Generate natural language explanations and summaries for financial reports.

**Service**: AI Narrative Generation Service (Port 8004)
**Demo Page**: http://localhost:5000/narrative-demo.html

### How to Use

#### Step 1: Access the Narrative Demo
1. Navigate to: http://localhost:5000/narrative-demo.html
2. Select the report type you want to explain

#### Step 2: Select Report Type

**Available Reports**:
- Income Statement (P&L)
- Balance Sheet
- Cash Flow Statement
- Trial Balance
- Variance Analysis (Budget vs Actual)

#### Step 3: Choose Narrative Style

**Management Summary** (Default):
- Concise, high-level overview
- 2-3 paragraphs
- Focus on key highlights and trends
- Suitable for: Board reports, executive summaries

**Detailed Analysis**:
- In-depth explanation
- 5-7 paragraphs
- Includes ratios, trends, comparisons
- Suitable for: Management meetings, investor reports

**Technical Commentary**:
- Accounting-focused explanation
- Detailed line-item analysis
- GAAP/IFRS compliance notes
- Suitable for: Audit documentation, technical reviews

#### Step 4: Generate Narrative
Click "Generate Narrative" - the AI will:
1. Fetch financial data from the selected report
2. Analyze key metrics and trends
3. Calculate relevant ratios
4. Generate natural language explanation

#### Step 5: Review and Edit Narrative

**Example: Income Statement Narrative (Management Summary)**

```
Financial Performance Summary - September 2025

Revenue Performance:
The company generated total revenue of AED 2,450,000 in September 2025,
representing a 12% increase compared to the prior month (AED 2,187,500).
This growth was primarily driven by a 15% increase in Product Sales
(AED 1,680,000) and stable Service Revenue (AED 770,000).

Cost Management:
Total operating expenses amounted to AED 1,835,000, yielding a gross
margin of 25.1% (AED 615,000). Cost of Goods Sold increased by 8% to
AED 1,120,000, which is below revenue growth, indicating improved
operational efficiency.

Profitability:
Net income for the period was AED 615,000, representing a net margin of
25.1%. This reflects a AED 95,000 improvement over the prior month,
demonstrating strong cost control and revenue growth.

Key Ratios:
- Gross Profit Margin: 25.1% (Industry average: 22%)
- Operating Margin: 25.1% (Prior month: 23.8%)
- Return on Sales: 25.1% (Target: 20%)

Outlook:
The positive trend in revenue growth combined with controlled expenses
positions the company favorably for Q4 2025. Management recommends
maintaining current operational strategies while exploring opportunities
to further optimize COGS.
```

#### Step 6: Customize and Export

**Edit Options**:
- ✏️ **Edit Text**: Click to modify AI-generated text
- 🔄 **Regenerate**: Click to get alternative narrative
- 📊 **Add Charts**: Insert supporting visualizations
- 📄 **Export**: Save as PDF, Word, or HTML

**Export Formats**:
- **PDF**: For board packs and presentations
- **Word (.docx)**: For further editing and customization
- **HTML**: For email or web publishing
- **Plain Text**: For copy-paste into other documents

### Real-World Example

**Scenario**: Finance Manager needs to prepare monthly board report

**Process**:
1. Select "Income Statement" report type
2. Choose "Management Summary" style
3. Generate narrative for September 2025
4. Review AI-generated text
5. Edit specific sections (add context about one-time expense)
6. Export as PDF
7. Attach to board pack

**Time Saved**: Manual report writing (45 minutes) → AI-assisted (10 minutes)

### Narrative Features

**AI Analyzes**:
- Period-over-period changes (month-over-month, year-over-year)
- Key performance indicators (margins, ratios)
- Variance from budget or forecast
- Industry benchmarks (if available)
- Trend analysis (improving, declining, stable)

**AI Highlights**:
- ✅ Positive trends (revenue growth, margin improvement)
- ⚠️ Areas of concern (cost increases, declining margins)
- 📈 Key metrics above targets
- 📉 Key metrics below targets
- 💡 Actionable insights and recommendations

### Use Cases

1. **Monthly Board Reports**: Generate executive summaries automatically
2. **Investor Updates**: Create quarterly performance narratives
3. **Management Commentary**: Add narrative to financial statements
4. **Audit Documentation**: Generate explanations for significant variances
5. **Budget Presentations**: Explain budget vs actual differences
6. **Stakeholder Communication**: Simplify financial data for non-finance audiences

### Tips for Better Narratives

✅ **Do**:
- Review and edit AI-generated text
- Add company-specific context
- Include forward-looking statements
- Customize tone for your audience
- Combine with visualizations (charts, graphs)

❌ **Don't**:
- Use AI narratives without review
- Include confidential data in external reports
- Rely solely on AI for critical investor communications
- Forget to fact-check numbers
- Use overly technical language for non-finance audiences

---

## 5. AI Policy Advisor

**Purpose**: Get instant answers to policy questions using your company's financial policies and procedures.

**Service**: AI Policy Advisor Service (Port 8005)
**Demo Page**: http://localhost:5000/policy-demo.html

### How to Use

#### Step 1: Access the Policy Advisor
1. Navigate to: http://localhost:5000/policy-demo.html
2. You'll see a question input field and chat interface

#### Step 2: Ask a Policy Question

**Question Types Supported**:

**Approval Limits**:
- "What is the approval threshold for expense reimbursements?"
- "Who needs to approve purchase orders over 10,000 AED?"
- "What is the signing authority for vendor payments?"

**Expense Policies**:
- "Are travel expenses reimbursable for economy class?"
- "What is the per diem rate for international travel?"
- "Can I expense client entertainment meals?"

**Procurement Policies**:
- "How many vendor quotes are required for purchases over 5,000 AED?"
- "What is the process for adding a new vendor?"
- "Are credit card purchases allowed for office supplies?"

**Accounting Policies**:
- "What is the depreciation method for computer equipment?"
- "How do we recognize revenue for multi-year contracts?"
- "What is the capitalization threshold for fixed assets?"

**Compliance Questions**:
- "What documents are required for audit retention?"
- "How long must we keep accounting records?"
- "What is the segregation of duties policy?"

#### Step 3: Submit Your Question
Type your question in natural language (no special formatting required) and click "Ask Policy Advisor"

#### Step 4: Review AI Response

**Response Format**:
```
Question: What is the approval threshold for expense reimbursements?

Answer:
Based on your company's Expense Reimbursement Policy (Section 3.2),
the approval thresholds are:

• Up to AED 500: Manager approval
• AED 501 - AED 2,000: Department Head approval
• AED 2,001 - AED 10,000: Finance Manager approval
• Above AED 10,000: CFO approval required

Additional Requirements:
- All reimbursements require original receipts
- Expense reports must be submitted within 30 days
- Non-compliant expenses will be rejected

Source: Expense Reimbursement Policy v2.3, Section 3.2
Last Updated: January 15, 2025
```

**Response Includes**:
- ✅ **Direct Answer**: Clear, concise response to your question
- 📚 **Source Reference**: Which policy document and section
- 📅 **Last Updated**: When the policy was last reviewed
- 💡 **Related Information**: Additional context or requirements
- ⚠️ **Exceptions**: Special cases or circumstances

#### Step 5: Follow-Up Questions
Ask clarifying questions in the chat:

**Example Conversation**:
```
You: What is the approval threshold for expense reimbursements?
AI: [Provides answer above]

You: What if it's an urgent expense over 10,000 AED and the CFO is unavailable?
AI: According to the Emergency Approval Procedure (Section 8.1), if the
    CFO is unavailable:
    • The COO may approve expenses up to 25,000 AED
    • CEO approval required for amounts above 25,000 AED
    • CFO must be notified within 24 hours of emergency approval

    Source: Emergency Approval Procedure v1.2, Section 8.1

You: How do I notify the CFO?
AI: Submit notification via:
    1. Email to cfo@company.com with subject "Emergency Approval Notification"
    2. Include: Amount, vendor, reason for urgency, approver name
    3. Attach supporting documentation

    Source: Emergency Approval Procedure v1.2, Section 8.3
```

### How RAG (Retrieval-Augmented Generation) Works

**Step 1: Document Indexing**
Your company's policy documents are:
1. Converted to text
2. Split into chunks
3. Converted to vector embeddings
4. Stored in Qdrant vector database

**Step 2: Query Processing**
When you ask a question:
1. Question is converted to vector embedding
2. Most relevant policy sections are retrieved
3. Context is sent to AI model
4. AI generates answer based on actual policy text

**Step 3: Answer Generation**
AI provides:
- Direct answer from your policies (not generic advice)
- Source citations (section and document)
- Confidence score (high/medium/low)

### Real-World Example

**Scenario**: Employee wants to reimburse 1,250 AED for client dinner

**Question**: "Can I expense a client dinner that cost 1,250 AED?"

**AI Response**:
```
Answer: Yes, with the following requirements:

Client entertainment meals are reimbursable under the following conditions:
• Maximum amount: AED 200 per person
• Approval required: Department Head (for amounts over AED 500)
• Documentation required:
  - Original itemized receipt
  - List of attendees (names, companies)
  - Business purpose statement

For your AED 1,250 expense:
• Ensure you have 6 or fewer attendees (AED 1,250 ÷ AED 200 = 6.25)
• If more than 6 attendees, only AED 1,200 will be approved
• Submit within 30 days with all required documentation
• Obtain Department Head pre-approval

⚠️ Note: Alcohol expenses are NOT reimbursable per UAE compliance
          requirements (Policy Section 4.5)

Source: Entertainment Expense Policy v1.8, Sections 4.2, 4.3, 4.5
Last Updated: March 1, 2025
```

**Employee Action**: Checks attendee count (5 people), submits with documentation, gets Department Head approval. Expense approved.

### Policy Documents Supported

The AI can search across:
- ✅ Financial Policies & Procedures Manual
- ✅ Expense Reimbursement Policy
- ✅ Procurement Policy
- ✅ Travel & Entertainment Policy
- ✅ Approval Authority Matrix
- ✅ Chart of Accounts Documentation
- ✅ Accounting Standards (GAAP/IFRS references)
- ✅ Audit & Compliance Procedures
- ✅ Internal Control Manual

**Note**: Your administrator must upload policy documents to the system for RAG to work.

### Use Cases

1. **Employee Self-Service**: Reduce HR/Finance inquiries
2. **New Employee Onboarding**: Quick policy reference
3. **Compliance Training**: Interactive policy Q&A
4. **Audit Preparation**: Find policy citations quickly
5. **Policy Updates**: Verify current policy version
6. **Decision Support**: Get guidance on edge cases

### Tips for Better Policy Answers

✅ **Do**:
- Ask specific questions (not vague)
- Include relevant context (amounts, departments)
- Ask follow-up questions for clarification
- Reference the source citations provided
- Verify critical policy information with Finance/HR

❌ **Don't**:
- Ask questions outside policy scope (AI won't make up answers)
- Rely on AI for legal advice (consult legal counsel)
- Assume policies haven't changed (check "Last Updated" date)
- Skip reading the actual policy document for critical decisions
- Share confidential policy information externally

### Limitations

**AI Policy Advisor CAN**:
- ✅ Search and retrieve policy text
- ✅ Summarize complex policies
- ✅ Provide citations and references
- ✅ Answer specific policy questions

**AI Policy Advisor CANNOT**:
- ❌ Create new policies
- ❌ Override existing policies
- ❌ Provide legal advice
- ❌ Answer questions about policies not in the database
- ❌ Make judgment calls on gray areas (escalate to manager)

---

## 6. ChatERP (Natural Language Query)

**Purpose**: Query your financial data using natural language - no SQL knowledge required.

**Service**: ChatERP Query Parser Service (Port 8006)
**Demo Page**: http://localhost:5000/chaterp.html

### How to Use

#### Step 1: Access ChatERP
1. Navigate to: http://localhost:5000/chaterp.html
2. You'll see a chat interface similar to ChatGPT

#### Step 2: Ask a Question in Plain English

**Example Questions**:

**Simple Queries**:
- "Show me all invoices from last month"
- "What is our current cash balance?"
- "List all vendors in the system"
- "How many journal entries were posted today?"

**Complex Queries**:
- "Show me unpaid invoices over 10,000 AED that are more than 30 days overdue"
- "What were our top 5 expenses in September 2025?"
- "Compare revenue from Q3 2024 vs Q3 2025"
- "Show me all journal entries posted by John Smith last week"

**Analytical Queries**:
- "What is the average invoice amount by vendor?"
- "Calculate total revenue by product category"
- "Show me aging analysis for accounts receivable"
- "What percentage of expenses are travel-related?"

#### Step 3: Review Query Interpretation

**ChatERP shows you**:
1. **Interpreted Intent**: What it thinks you're asking
2. **Generated SQL**: The actual database query
3. **Confidence Score**: How confident it is (0-100%)

**Example**:
```
Your Question: "Show me unpaid invoices over 10,000 AED"

Interpreted Intent: Retrieve AP invoices with status 'unpaid' and
                   total_amount > 10000

Generated SQL:
SELECT invoice_number, vendor_name, invoice_date, total_amount, days_overdue
FROM ap_invoices
WHERE payment_status = 'unpaid'
  AND total_amount > 10000
  AND tenant_id = '00000000-0000-0000-0000-000000000001'
ORDER BY invoice_date DESC

Confidence: 95%
```

#### Step 4: Approve or Modify Query

**High Confidence (90-100%)**: ✅ Execute immediately
- SQL looks correct
- Intent matches your question
- Safe to run

**Medium Confidence (70-89%)**: ⚠️ Review before executing
- Check SQL for accuracy
- Verify table/column names
- May need refinement

**Low Confidence (<70%)**: ❌ Rephrase question
- AI unsure about intent
- May produce incorrect results
- Ask more specific question

**Actions**:
- **✅ Execute Query**: Run the SQL and see results
- **✏️ Edit SQL**: Modify the generated SQL manually
- **❌ Cancel**: Rephrase your question
- **💡 Suggest Better Query**: Ask AI to refine

#### Step 5: View Results

**Results Display**:
```
Query Results: 5 invoices found

┌─────────────────┬─────────────────────┬──────────────┬──────────────┬──────────────┐
│ Invoice Number  │ Vendor Name         │ Invoice Date │ Amount (AED) │ Days Overdue │
├─────────────────┼─────────────────────┼──────────────┼──────────────┼──────────────┤
│ INV-AP-2025-042 │ Emirates IT Solutions│ 2025-09-15   │ 45,000.00    │ 35 days      │
│ INV-AP-2025-038 │ Office Supplies LLC │ 2025-09-20   │ 12,500.00    │ 30 days      │
│ INV-AP-2025-033 │ Dubai Consulting    │ 2025-09-25   │ 18,750.00    │ 25 days      │
│ INV-AP-2025-029 │ Tech Equipment Ltd  │ 2025-09-28   │ 22,000.00    │ 22 days      │
│ INV-AP-2025-025 │ Facility Management │ 2025-10-01   │ 15,600.00    │ 19 days      │
└─────────────────┴─────────────────────┴──────────────┴──────────────┴──────────────┘

Total Amount: AED 113,850.00
```

#### Step 6: Export or Take Action

**Export Options**:
- 📊 **Excel**: Download as .xlsx file
- 📄 **CSV**: Download as .csv file
- 📋 **Copy**: Copy to clipboard
- 📧 **Email**: Send results via email

**Action Options**:
- 💳 **Pay Selected**: Mark invoices for payment
- 📨 **Send Reminder**: Email vendor payment reminder
- 🔍 **Drill Down**: Click invoice to see full details
- 📊 **Visualize**: Create chart from results

### Query Templates

**Pre-built queries you can customize**:

**Financial Overview**:
- "What is my current cash position?"
- "Show me this month's revenue"
- "What are my top 10 expenses?"

**AP/AR Management**:
- "List all overdue invoices"
- "Show me invoices due this week"
- "What is my total accounts receivable?"

**Journal Entries**:
- "Show me today's journal entries"
- "Find all entries posted by [user]"
- "Show me entries for account [account_code]"

**Vendor/Customer Analysis**:
- "Who are my top 5 vendors by spend?"
- "Show me customers with outstanding balances"
- "Which vendors have we paid this month?"

**Reporting**:
- "Generate trial balance"
- "Show me account balances"
- "What is my profit for this month?"

### Real-World Example

**Scenario**: Finance Manager needs to review large overdue AP invoices before board meeting

**Conversation**:
```
User: Show me all unpaid invoices over 20,000 AED that are more than 30 days old

ChatERP: [Generates and displays SQL]
Results: 3 invoices found
• INV-AP-2025-042: Emirates IT - 45,000 AED (35 days overdue)
• INV-AP-2025-033: Dubai Consulting - 18,750 AED (25 days old) ❌ Not 30+ days
• INV-AP-2025-029: Tech Equipment - 22,000 AED (22 days old) ❌ Not 30+ days

User: Wait, that's not right. Two of these aren't 30+ days old.

ChatERP: You're correct. Let me refine the query to only show invoices
         with days_overdue >= 30.

[Generates corrected SQL]
Results: 1 invoice found
• INV-AP-2025-042: Emirates IT - 45,000 AED (35 days overdue)

User: Perfect. Send payment reminder to this vendor.

ChatERP: ✅ Payment reminder email sent to Emirates IT Solutions
         Subject: "Outstanding Invoice INV-AP-2025-042 - 35 Days Overdue"
```

### Natural Language Capabilities

**ChatERP Understands**:
- **Time References**: "last month", "this week", "yesterday", "Q3 2025"
- **Comparisons**: "greater than", "less than", "between", "top 5"
- **Aggregations**: "total", "average", "count", "sum"
- **Sorting**: "highest", "lowest", "most recent", "oldest"
- **Filtering**: "unpaid", "overdue", "posted", "active"
- **Joins**: "invoices with vendor names", "entries with account details"

**Example Translations**:
```
"Last month" → WHERE EXTRACT(MONTH FROM date) = EXTRACT(MONTH FROM CURRENT_DATE - INTERVAL '1 month')
"Over 10,000 AED" → WHERE amount > 10000
"Top 5" → ORDER BY amount DESC LIMIT 5
"Unpaid" → WHERE payment_status = 'unpaid'
```

### Security & Permissions

**What ChatERP CAN Do**:
- ✅ SELECT queries (read data)
- ✅ Aggregate functions (SUM, AVG, COUNT)
- ✅ JOIN tables
- ✅ Filter by tenant_id automatically

**What ChatERP CANNOT Do**:
- ❌ INSERT, UPDATE, DELETE data
- ❌ DROP tables or modify schema
- ❌ Access data from other tenants
- ❌ Execute stored procedures
- ❌ Bypass permissions

**Built-in Safety**:
- All queries automatically filtered by your tenant_id
- Read-only access (no data modification)
- Query timeout (max 30 seconds)
- Result limit (max 1000 rows)

### Use Cases

1. **Ad-hoc Reporting**: Quick answers without waiting for IT
2. **Executive Dashboards**: Build custom views
3. **Compliance Checks**: Query data for audits
4. **Data Exploration**: Discover insights in your data
5. **Training**: Learn database structure through natural language
6. **Customer Service**: Answer customer inquiries quickly

### Tips for Better Queries

✅ **Do**:
- Be specific ("last month" vs "recently")
- Include relevant filters (amounts, dates, status)
- Start simple, then refine
- Review generated SQL before executing
- Use templates as starting points

❌ **Don't**:
- Ask vague questions ("show me everything")
- Use ambiguous time references ("a while ago")
- Request data modifications (use proper screens)
- Ignore low confidence scores
- Share results containing sensitive data

### Common Questions & Answers

**Q: Can ChatERP create journal entries?**
A: No, ChatERP is read-only. Use the Journal Entry form (post-je.html) to create entries.

**Q: Why does my query return no results?**
A: Check:
1. Date range (data might be outside your filter)
2. Spelling of vendor/account names
3. Status filters (posted vs draft entries)
4. Tenant isolation (only see your company's data)

**Q: Can I save my favorite queries?**
A: Yes! Click the ⭐ star icon to save queries to "My Queries" for quick re-use.

**Q: How do I learn what tables/fields are available?**
A: Click "Show Schema" to see database structure, or ask ChatERP: "What tables are available?"

**Q: Is my data secure?**
A: Yes. All queries:
- Are automatically filtered by your tenant_id
- Are read-only (no modifications allowed)
- Are logged for audit purposes
- Respect your role-based permissions

---

## Troubleshooting

### AI Services Not Responding

**Symptom**: AI service returns timeout or connection error

**Solutions**:
1. Check service status:
   ```bash
   docker ps --filter "name=ai"
   ```
2. Verify all AI containers are "healthy"
3. Restart unhealthy services:
   ```bash
   docker restart airp-ai-[service-name]
   ```
4. Check logs for errors:
   ```bash
   docker logs airp-ai-[service-name] --tail 50
   ```

### Low Confidence Scores

**Symptom**: AI returns confidence score <50%

**Solutions**:
1. **Rephrase your question**: Use more specific language
2. **Add context**: Include amounts, dates, or other details
3. **Use examples**: "Like invoice ABC-123"
4. **Check spelling**: Verify vendor/account names
5. **Break into smaller questions**: Simplify complex queries

### Incorrect Classification

**Symptom**: AI classifies to wrong GL account

**Solutions**:
1. **Provide more details**: Add vendor name and amount
2. **Review reasoning**: Check AI explanation for logic
3. **Manual override**: Select correct account and provide feedback
4. **Update training data**: Corrections improve future accuracy
5. **Check confidence**: Low confidence = needs review

### Reconciliation Mismatches

**Symptom**: AI matches wrong transactions

**Solutions**:
1. **Check match score**: Only accept matches >85%
2. **Review date ranges**: Ensure consistent periods
3. **Verify amounts**: Check for currency or decimal errors
4. **Investigate descriptions**: Bank may use different vendor names
5. **Manual reconciliation**: Some transactions require human judgment

### Forecast Inaccuracy

**Symptom**: Forecast doesn't match actual results

**Solutions**:
1. **Use more history**: Minimum 6 months, 12+ recommended
2. **Account for one-time events**: Large purchases skew predictions
3. **Update regularly**: Weekly/monthly re-forecasting
4. **Check seasonality**: Ensure seasonal patterns detected
5. **Adjust confidence intervals**: Use wider bounds (90% vs 80%)

### Policy Advisor No Answer

**Symptom**: "I couldn't find information about that policy"

**Solutions**:
1. **Rephrase question**: Use different keywords
2. **Check policy documents**: Ensure uploaded to system
3. **Verify Qdrant health**: `docker ps | grep qdrant`
4. **Ask simpler question**: Break complex queries into parts
5. **Contact admin**: Policy documents may need re-indexing

### ChatERP Query Errors

**Symptom**: Generated SQL fails to execute

**Solutions**:
1. **Review SQL**: Check for syntax errors
2. **Verify table names**: Use "Show Schema" to confirm
3. **Rephrase question**: AI may have misunderstood intent
4. **Check permissions**: Ensure you have access to requested data
5. **Report bug**: If SQL looks correct but fails, report to admin

---

## Best Practices

### General AI Usage

✅ **Always Review AI Output**
- Don't blindly trust AI suggestions
- Verify critical data and decisions
- Use AI as an assistant, not a replacement for judgment

✅ **Provide Context**
- Include amounts, dates, vendor names
- Reference specific accounts or transactions
- Give examples when possible

✅ **Start Simple**
- Begin with basic questions
- Add complexity as you understand AI behavior
- Build on successful queries

✅ **Monitor Confidence Scores**
- High (>85%): Generally safe to use
- Medium (70-85%): Review carefully
- Low (<70%): Requires manual verification

✅ **Provide Feedback**
- Correct AI mistakes to improve accuracy
- Rate responses (thumbs up/down)
- Report bugs or incorrect behavior

### Data Security

✅ **Protect Sensitive Information**
- Don't share AI outputs containing PII externally
- Review data before exporting or emailing
- Follow company data classification policies

✅ **Verify Access Rights**
- Only query data you're authorized to see
- Don't share credentials with others
- Log out when finished

✅ **Audit Trail**
- All AI queries are logged
- Review your query history periodically
- Report suspicious activity

### Performance Optimization

✅ **Use Filters**
- Limit date ranges (last month vs all time)
- Filter by status (posted vs all entries)
- Specify accounts or vendors

✅ **Schedule Large Jobs**
- Run forecasts during off-peak hours
- Batch reconciliations at month-end
- Export large datasets overnight

✅ **Cache Results**
- Save frequently-used queries
- Export reports for offline review
- Use dashboard widgets for common metrics

### Training & Adoption

✅ **Start with Demos**
- Use demo pages to learn features
- Practice with sample data
- Review user manual examples

✅ **Train Your Team**
- Schedule group training sessions
- Create department-specific use cases
- Designate AI champions in each team

✅ **Document Your Processes**
- Save successful query templates
- Document classification rules
- Share tips with colleagues

---

## Quick Reference Card

### AI Service URLs
```
AI Classification:  http://localhost:8001/classify
AI Reconciliation:  http://localhost:8002/reconcile
AI Forecasting:     http://localhost:8003/forecast
AI Narrative:       http://localhost:8004/generate-narrative
AI Policy Advisor:  http://localhost:8005/advise
ChatERP:            http://localhost:8006/parse-query
```

### Demo Pages
```
Classification:  http://localhost:5000/classify-demo.html
Reconciliation:  http://localhost:5000/recon-demo.html
Forecasting:     http://localhost:5000/cashflow-demo.html
Narrative:       http://localhost:5000/narrative-demo.html
Policy Advisor:  http://localhost:5000/policy-demo.html
ChatERP:         http://localhost:5000/chaterp.html
```

### Confidence Score Guide
```
90-100%  ✅ High - Safe to use automatically
70-89%   ⚠️ Medium - Review before using
50-69%   ⚠️ Low - Requires verification
<50%     ❌ Very Low - Manual processing needed
```

### Support Contacts
```
Technical Support:  support@yourcompany.com
AI Service Issues:  ai-support@yourcompany.com
Documentation:      docs.yourcompany.com/airp
Training:           training@yourcompany.com
```

---

## Appendix: Sample Use Cases by Role

### For Accountants
- **Daily**: Use ChatERP to check account balances
- **Weekly**: Run bank reconciliation with AI matching
- **Monthly**: Generate narratives for financial reports
- **Quarterly**: Forecast cash flow for next quarter

### For AP/AR Clerks
- **Daily**: Classify incoming invoices automatically
- **Weekly**: Review aging reports and send reminders
- **Monthly**: Reconcile vendor/customer statements
- **As Needed**: Query overdue invoices with ChatERP

### For Finance Managers
- **Daily**: Review AI classification suggestions
- **Weekly**: Analyze cash flow forecasts
- **Monthly**: Generate board report narratives
- **Quarterly**: Variance analysis with ChatERP

### For CFOs
- **Weekly**: Review cash forecast alerts
- **Monthly**: Review AI-generated management commentary
- **Quarterly**: Analyze trends with ChatERP queries
- **As Needed**: Query policy advisor for compliance questions

### For Auditors
- **During Audit**: Query specific transactions with ChatERP
- **Testing**: Verify AI classification accuracy
- **Documentation**: Use policy advisor to find procedures
- **Reporting**: Generate narratives for audit findings

---

**Document Version**: 1.0
**Last Updated**: October 20, 2025
**Feedback**: Please report errors or suggestions to documentation@yourcompany.com

---

*This user manual is designed to help you maximize the value of AIRP's AI-powered features. For additional training or support, please contact your system administrator.*
