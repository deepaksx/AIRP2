# AIRP v2.10.1 - Comprehensive Automated Test Plan

**Test Execution Date**: October 19, 2025
**Version Under Test**: v2.10.1
**Tester**: Automated Testing Suite

---

## Test Coverage Overview

This document outlines the comprehensive test plan for all features listed in CURRENT_FEATURES.md.

### Test Categories:

1. **Core Accounting Features** (10 tests)
2. **Journal Entry Management** (15 tests)
3. **Sub-Ledger Management** (12 tests)
4. **Financial Reporting** (20 tests)
5. **AI-Powered Features** (6 tests)
6. **Architecture & Data Integrity** (8 tests)
7. **User Interface Pages** (20 tests)

**Total Tests**: 91 tests

---

## Test Execution Plan

### Phase 1: Infrastructure & Services
- Verify all backend services are running
- Verify database connectivity
- Verify API endpoints are accessible

### Phase 2: Core Accounting Features
- Test double-entry bookkeeping validation
- Test Chart of Accounts (51 accounts)
- Test account loading in UI
- Test multi-currency support

### Phase 3: Journal Entry Management
- Test entry posting with all 8 entry natures
- Test validation rules (6 rules)
- Test vendor/customer dynamic sections
- Test balance verification

### Phase 4: Sub-Ledger Management
- Test AP invoice creation and tracking
- Test AR invoice creation and tracking
- Test vendor ledger
- Test customer ledger
- Test sub-ledger to GL reconciliation

### Phase 5: Financial Reporting
- Test Trial Balance (with zero-balance toggle)
- Test Income Statement
- Test Balance Sheet
- Test Cash Flow Statement
- Test GL Line Items (with total row)
- Test Journal Entry Register
- Test Vendor/Customer Ledgers

### Phase 6: AI Features
- Test AI Classification Service
- Test AI Reconciliation Service
- Test AI Forecasting Service
- Test AI Narrative Generation
- Test AI Policy Advisor
- Test ChatERP Query Parser

### Phase 7: UI Pages
- Test all 20+ HTML pages load correctly
- Test navigation
- Test responsive design

### Phase 8: Data Integrity
- Test event sourcing
- Test CQRS projections
- Test audit trail
- Test immutability

---

## Test Result Format

Each test iteration will report:

```
✅ PASS - Test passed completely
⚠️ PARTIAL - Test passed with minor issues
❌ FAIL - Test failed
⏭️ SKIP - Test skipped (dependency missing)
```

---

## Detailed Test Cases

### Category 1: Core Accounting Features

**TEST-001**: Verify all backend services are running
**TEST-002**: Verify Chart of Accounts has 51 accounts
**TEST-003**: Verify bank accounts (1010-1090) are present
**TEST-004**: Test double-entry balance validation
**TEST-005**: Test account dropdown loads all 51 accounts
**TEST-006**: Verify account types (Asset, Liability, Equity, Revenue, Expense)
**TEST-007**: Test multi-currency fields exist
**TEST-008**: Test fiscal period tracking
**TEST-009**: Verify normal balance rules
**TEST-010**: Test account hierarchy

### Category 2: Journal Entry Management

**TEST-011**: Test entry nature dropdown (8 options)
**TEST-012**: Test posting with "General Entry" nature
**TEST-013**: Test posting with "AP Invoice" nature
**TEST-014**: Test posting with "AR Invoice" nature
**TEST-015**: Test posting with "Payment" nature
**TEST-016**: Test posting with "Bank Transaction" nature
**TEST-017**: Test validation: Entry nature required
**TEST-018**: Test validation: Date required
**TEST-019**: Test validation: Description required
**TEST-020**: Test validation: Minimum 2 lines required
**TEST-021**: Test validation: Balance check (DR = CR)
**TEST-022**: Test validation: Vendor required for AP (2100)
**TEST-023**: Test validation: Customer required for AR (1200)
**TEST-024**: Test dynamic vendor section appearance
**TEST-025**: Test dynamic customer section appearance

### Category 3: Sub-Ledger Management

**TEST-026**: Create AP invoice via AP service
**TEST-027**: Verify AP invoice in vendor ledger
**TEST-028**: Verify AP invoice creates GL entry
**TEST-029**: Test vendor ledger reconciliation to GL 2100
**TEST-030**: Create AR invoice via AR service
**TEST-031**: Verify AR invoice in customer ledger
**TEST-032**: Verify AR invoice creates GL entry
**TEST-033**: Test customer ledger reconciliation to GL 1200
**TEST-034**: Test AP aging report
**TEST-035**: Test AR aging report
**TEST-036**: Verify dimension-based tracking (vendor_id, customer_id)
**TEST-037**: Test sub-ledger variance detection

### Category 4: Financial Reporting

**TEST-038**: Load Trial Balance report
**TEST-039**: Verify Trial Balance has all account types
**TEST-040**: Test zero-balance toggle ON by default
**TEST-041**: Test zero-balance toggle switches correctly
**TEST-042**: Verify Trial Balance totals (DR = CR)
**TEST-043**: Load Income Statement
**TEST-044**: Verify Income Statement has Revenue section
**TEST-045**: Verify Income Statement has Expense section
**TEST-046**: Verify Income Statement calculates Net Income
**TEST-047**: Load Balance Sheet
**TEST-048**: Verify Balance Sheet has Assets section
**TEST-049**: Verify Balance Sheet has Liabilities section
**TEST-050**: Verify Balance Sheet has Equity section
**TEST-051**: Verify accounting equation (Assets = Liabilities + Equity)
**TEST-052**: Load Cash Flow Statement
**TEST-053**: Load GL Line Items report
**TEST-054**: Verify GL Line Items has total row
**TEST-055**: Verify GL Line Items total balance = 0.00
**TEST-056**: Load Journal Entry Register
**TEST-057**: Test JE drilldown modal
**TEST-058**: Load Vendor Ledger
**TEST-059**: Test vendor ledger reconciliation display
**TEST-060**: Load Customer Ledger
**TEST-061**: Test customer ledger reconciliation display
**TEST-062**: Load Account Balances report

### Category 5: AI-Powered Features

**TEST-063**: Test AI Classification Service (Port 8001)
**TEST-064**: Test AI Reconciliation Service (Port 8002)
**TEST-065**: Test AI Forecasting Service (Port 8003)
**TEST-066**: Test AI Narrative Generation (Port 8004)
**TEST-067**: Test AI Policy Advisor (Port 8005)
**TEST-068**: Test ChatERP Query Parser (Port 8006)

### Category 6: Architecture & Data Integrity

**TEST-069**: Verify event_store table exists
**TEST-070**: Verify events are created for journal entries
**TEST-071**: Verify event checksums (SHA-256)
**TEST-072**: Verify gl_balances projection exists
**TEST-073**: Verify trial_balance materialized view
**TEST-074**: Test multi-tenancy (tenant_id isolation)
**TEST-075**: Verify audit trail fields (created_by, posted_by)
**TEST-076**: Test immutability (no deletions, reversals only)

### Category 7: User Interface Pages

**TEST-077**: Load index.html (main dashboard)
**TEST-078**: Load post-je.html (journal entry form)
**TEST-079**: Load trial-balance.html
**TEST-080**: Load income-statement.html
**TEST-081**: Load balance-sheet.html
**TEST-082**: Load cash-flow-statement.html
**TEST-083**: Load gl-line-items.html
**TEST-084**: Load je-register.html
**TEST-085**: Load account-balances.html
**TEST-086**: Load vendor-ledger.html
**TEST-087**: Load customer-ledger.html
**TEST-088**: Load chaterp.html
**TEST-089**: Load database-explorer.html
**TEST-090**: Load master-data.html
**TEST-091**: Test navigation between pages

---

## Test Execution Log

Test results will be appended below as each iteration completes.

---

*Test Plan Created: October 19, 2025*
*Ready for Execution*
