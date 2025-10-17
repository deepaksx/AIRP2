-- ============================================
-- AIRP v2.0 - Database Schema
-- Event-Sourced Immutable Ledger
-- PostgreSQL 15+ with Partitioning
-- Region: Dubai/UAE (UTC+4)
-- Compliance: IFRS, GAAP, UAE VAT
-- ============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Set timezone
SET timezone = 'Asia/Dubai';

-- ============================================
-- MASTER SCHEMA - Shared Tables
-- ============================================

-- Tenants/Entities
CREATE TABLE IF NOT EXISTS tenants (
    tenant_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_code VARCHAR(20) UNIQUE NOT NULL,
    legal_name VARCHAR(255) NOT NULL,
    base_currency CHAR(3) NOT NULL DEFAULT 'AED',
    timezone VARCHAR(50) NOT NULL DEFAULT 'Asia/Dubai',
    accounting_standard VARCHAR(10) NOT NULL DEFAULT 'IFRS', -- IFRS or GAAP
    fiscal_year_end DATE NOT NULL,
    vat_registered BOOLEAN DEFAULT true,
    vat_rate DECIMAL(5,4) DEFAULT 0.0500, -- 5% UAE VAT
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB
);

CREATE INDEX idx_tenants_code ON tenants(tenant_code);
CREATE INDEX idx_tenants_status ON tenants(status);

-- Chart of Accounts (Multi-Tenant)
CREATE TABLE IF NOT EXISTS chart_of_accounts (
    account_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    account_code VARCHAR(50) NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) NOT NULL, -- Asset, Liability, Equity, Revenue, Expense
    account_subtype VARCHAR(50),
    parent_account_id UUID REFERENCES chart_of_accounts(account_id),
    normal_balance VARCHAR(10) NOT NULL, -- Debit or Credit
    is_control_account BOOLEAN DEFAULT false,
    is_leaf BOOLEAN DEFAULT true,
    currency CHAR(3) NOT NULL DEFAULT 'AED',
    status VARCHAR(20) DEFAULT 'active',
    ifrs_category VARCHAR(100),
    gaap_category VARCHAR(100),
    tax_category VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(tenant_id, account_code)
);

CREATE INDEX idx_coa_tenant ON chart_of_accounts(tenant_id);
CREATE INDEX idx_coa_type ON chart_of_accounts(account_type);
CREATE INDEX idx_coa_code ON chart_of_accounts(account_code);
CREATE INDEX idx_coa_parent ON chart_of_accounts(parent_account_id);

-- ============================================
-- EVENT STORE - Immutable Append-Only
-- Partitioned by month for performance
-- ============================================

CREATE TABLE IF NOT EXISTS event_store (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    aggregate_id UUID NOT NULL, -- Transaction ID, Invoice ID, etc.
    aggregate_type VARCHAR(50) NOT NULL, -- JournalEntry, APInvoice, ARInvoice, Payment, etc.
    event_type VARCHAR(100) NOT NULL, -- TransactionCreated, JournalPosted, InvoiceApproved, etc.
    event_version INTEGER NOT NULL DEFAULT 1,
    event_data JSONB NOT NULL,
    event_metadata JSONB,
    causation_id UUID, -- What caused this event
    correlation_id UUID, -- Group related events
    user_id UUID,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sequence_number BIGSERIAL,
    checksum VARCHAR(64) -- SHA-256 hash for integrity
) PARTITION BY RANGE (timestamp);

-- Create partitions for 24 months (2 years)
CREATE TABLE event_store_2024_01 PARTITION OF event_store
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE event_store_2024_02 PARTITION OF event_store
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE event_store_2024_03 PARTITION OF event_store
    FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');
CREATE TABLE event_store_2024_04 PARTITION OF event_store
    FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');
CREATE TABLE event_store_2024_05 PARTITION OF event_store
    FOR VALUES FROM ('2024-05-01') TO ('2024-06-01');
CREATE TABLE event_store_2024_06 PARTITION OF event_store
    FOR VALUES FROM ('2024-06-01') TO ('2024-07-01');
CREATE TABLE event_store_2024_07 PARTITION OF event_store
    FOR VALUES FROM ('2024-07-01') TO ('2024-08-01');
CREATE TABLE event_store_2024_08 PARTITION OF event_store
    FOR VALUES FROM ('2024-08-01') TO ('2024-09-01');
CREATE TABLE event_store_2024_09 PARTITION OF event_store
    FOR VALUES FROM ('2024-09-01') TO ('2024-10-01');
CREATE TABLE event_store_2024_10 PARTITION OF event_store
    FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');
CREATE TABLE event_store_2024_11 PARTITION OF event_store
    FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');
CREATE TABLE event_store_2024_12 PARTITION OF event_store
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');
CREATE TABLE event_store_2025_01 PARTITION OF event_store
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE event_store_2025_02 PARTITION OF event_store
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE event_store_2025_03 PARTITION OF event_store
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE event_store_2025_04 PARTITION OF event_store
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE event_store_2025_05 PARTITION OF event_store
    FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE event_store_2025_06 PARTITION OF event_store
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE event_store_2025_07 PARTITION OF event_store
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE event_store_2025_08 PARTITION OF event_store
    FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE event_store_2025_09 PARTITION OF event_store
    FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE event_store_2025_10 PARTITION OF event_store
    FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE event_store_2025_11 PARTITION OF event_store
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE event_store_2025_12 PARTITION OF event_store
    FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

-- Indexes on event_store
CREATE INDEX idx_event_tenant ON event_store(tenant_id, timestamp DESC);
CREATE INDEX idx_event_aggregate ON event_store(aggregate_id);
CREATE INDEX idx_event_type ON event_store(event_type);
CREATE INDEX idx_event_correlation ON event_store(correlation_id);
CREATE INDEX idx_event_sequence ON event_store(sequence_number);

-- ============================================
-- PROJECTIONS - Read Models
-- ============================================

-- General Ledger Projection (Current Balances)
CREATE TABLE IF NOT EXISTS gl_balances (
    balance_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    account_id UUID NOT NULL REFERENCES chart_of_accounts(account_id),
    fiscal_year INTEGER NOT NULL,
    fiscal_period INTEGER NOT NULL,
    currency CHAR(3) NOT NULL,
    debit_amount DECIMAL(20,4) DEFAULT 0,
    credit_amount DECIMAL(20,4) DEFAULT 0,
    balance DECIMAL(20,4) DEFAULT 0,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    last_event_id UUID,
    UNIQUE(tenant_id, account_id, fiscal_year, fiscal_period, currency)
);

CREATE INDEX idx_gl_balances_tenant ON gl_balances(tenant_id);
CREATE INDEX idx_gl_balances_account ON gl_balances(account_id);
CREATE INDEX idx_gl_balances_period ON gl_balances(fiscal_year, fiscal_period);

-- Trial Balance View (Real-time)
CREATE MATERIALIZED VIEW trial_balance AS
SELECT
    tenant_id,
    fiscal_year,
    fiscal_period,
    account_id,
    SUM(debit_amount) as total_debits,
    SUM(credit_amount) as total_credits,
    SUM(balance) as ending_balance,
    MAX(last_updated) as as_of_date
FROM gl_balances
GROUP BY tenant_id, fiscal_year, fiscal_period, account_id;

CREATE INDEX idx_trial_balance_tenant ON trial_balance(tenant_id);

-- Journal Entries Projection
CREATE TABLE IF NOT EXISTS journal_entries (
    entry_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    entry_number VARCHAR(50) NOT NULL,
    entry_date DATE NOT NULL,
    posting_date DATE NOT NULL,
    entry_type VARCHAR(50) NOT NULL, -- Standard, Adjusting, Closing, Reversing
    source_type VARCHAR(50), -- AP, AR, Treasury, Manual, AI-Generated
    source_ref_id UUID,
    description TEXT,
    total_debit DECIMAL(20,4) NOT NULL,
    total_credit DECIMAL(20,4) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'AED',
    status VARCHAR(20) DEFAULT 'draft', -- draft, pending_approval, approved, posted, reversed
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    posted_by UUID,
    posted_at TIMESTAMPTZ,
    reversed_by UUID,
    reversed_at TIMESTAMPTZ,
    reversal_entry_id UUID,
    ai_confidence_score DECIMAL(5,4),
    ai_model_version VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(tenant_id, entry_number)
);

CREATE INDEX idx_je_tenant ON journal_entries(tenant_id);
CREATE INDEX idx_je_date ON journal_entries(entry_date);
CREATE INDEX idx_je_status ON journal_entries(status);
CREATE INDEX idx_je_source ON journal_entries(source_type, source_ref_id);

-- Journal Entry Lines
CREATE TABLE IF NOT EXISTS journal_entry_lines (
    line_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entry_id UUID NOT NULL REFERENCES journal_entries(entry_id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    line_number INTEGER NOT NULL,
    account_id UUID NOT NULL REFERENCES chart_of_accounts(account_id),
    debit_amount DECIMAL(20,4) DEFAULT 0,
    credit_amount DECIMAL(20,4) DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'AED',
    exchange_rate DECIMAL(12,6) DEFAULT 1.0,
    description TEXT,
    dimension_1 VARCHAR(50), -- Cost Center
    dimension_2 VARCHAR(50), -- Department
    dimension_3 VARCHAR(50), -- Project
    dimension_4 VARCHAR(50), -- Location
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(entry_id, line_number)
);

CREATE INDEX idx_jel_entry ON journal_entry_lines(entry_id);
CREATE INDEX idx_jel_account ON journal_entry_lines(account_id);
CREATE INDEX idx_jel_dimensions ON journal_entry_lines(dimension_1, dimension_2, dimension_3);

-- ============================================
-- ACCOUNTS PAYABLE (AP)
-- ============================================

-- Vendors
CREATE TABLE IF NOT EXISTS vendors (
    vendor_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    vendor_code VARCHAR(50) NOT NULL,
    vendor_name VARCHAR(255) NOT NULL,
    tax_id VARCHAR(50),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    payment_terms INTEGER DEFAULT 30, -- days
    default_currency CHAR(3) DEFAULT 'AED',
    bank_account_name VARCHAR(255),
    bank_account_number VARCHAR(50),
    bank_name VARCHAR(255),
    bank_swift VARCHAR(20),
    iban VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(tenant_id, vendor_code)
);

CREATE INDEX idx_vendors_tenant ON vendors(tenant_id);
CREATE INDEX idx_vendors_name ON vendors USING gin(vendor_name gin_trgm_ops);

-- AP Invoices
CREATE TABLE IF NOT EXISTS ap_invoices (
    invoice_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    vendor_id UUID NOT NULL REFERENCES vendors(vendor_id),
    invoice_number VARCHAR(100) NOT NULL,
    invoice_date DATE NOT NULL,
    due_date DATE NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'AED',
    subtotal DECIMAL(20,4) NOT NULL,
    tax_amount DECIMAL(20,4) DEFAULT 0,
    total_amount DECIMAL(20,4) NOT NULL,
    amount_paid DECIMAL(20,4) DEFAULT 0,
    amount_outstanding DECIMAL(20,4) NOT NULL,
    status VARCHAR(20) DEFAULT 'draft', -- draft, pending_approval, approved, paid, cancelled
    approval_status VARCHAR(20) DEFAULT 'pending',
    payment_status VARCHAR(20) DEFAULT 'unpaid', -- unpaid, partial, paid
    ai_extracted_data JSONB, -- OCR/AI extraction results
    ai_confidence_score DECIMAL(5,4),
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(tenant_id, vendor_id, invoice_number)
);

CREATE INDEX idx_ap_invoices_tenant ON ap_invoices(tenant_id);
CREATE INDEX idx_ap_invoices_vendor ON ap_invoices(vendor_id);
CREATE INDEX idx_ap_invoices_date ON ap_invoices(invoice_date);
CREATE INDEX idx_ap_invoices_due ON ap_invoices(due_date);
CREATE INDEX idx_ap_invoices_status ON ap_invoices(status, payment_status);

-- AP Invoice Lines
CREATE TABLE IF NOT EXISTS ap_invoice_lines (
    line_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES ap_invoices(invoice_id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    line_number INTEGER NOT NULL,
    description TEXT NOT NULL,
    quantity DECIMAL(12,4) DEFAULT 1,
    unit_price DECIMAL(20,4) NOT NULL,
    line_amount DECIMAL(20,4) NOT NULL,
    tax_rate DECIMAL(5,4) DEFAULT 0.05,
    tax_amount DECIMAL(20,4) DEFAULT 0,
    gl_account_id UUID REFERENCES chart_of_accounts(account_id),
    ai_suggested_account_id UUID REFERENCES chart_of_accounts(account_id),
    ai_confidence_score DECIMAL(5,4),
    dimension_1 VARCHAR(50),
    dimension_2 VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(invoice_id, line_number)
);

CREATE INDEX idx_ap_lines_invoice ON ap_invoice_lines(invoice_id);
CREATE INDEX idx_ap_lines_account ON ap_invoice_lines(gl_account_id);

-- AP Aging Projection
CREATE TABLE IF NOT EXISTS ap_aging (
    aging_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    vendor_id UUID NOT NULL REFERENCES vendors(vendor_id),
    invoice_id UUID NOT NULL REFERENCES ap_invoices(invoice_id),
    currency CHAR(3) NOT NULL,
    total_outstanding DECIMAL(20,4) NOT NULL,
    current_amount DECIMAL(20,4) DEFAULT 0, -- 0-30 days
    bucket_30 DECIMAL(20,4) DEFAULT 0,      -- 31-60 days
    bucket_60 DECIMAL(20,4) DEFAULT 0,      -- 61-90 days
    bucket_90 DECIMAL(20,4) DEFAULT 0,      -- 91-120 days
    bucket_120_plus DECIMAL(20,4) DEFAULT 0, -- 120+ days
    as_of_date DATE NOT NULL,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, invoice_id, as_of_date)
);

CREATE INDEX idx_ap_aging_tenant ON ap_aging(tenant_id);
CREATE INDEX idx_ap_aging_vendor ON ap_aging(vendor_id);
CREATE INDEX idx_ap_aging_date ON ap_aging(as_of_date);

-- ============================================
-- ACCOUNTS RECEIVABLE (AR)
-- ============================================

-- Customers
CREATE TABLE IF NOT EXISTS customers (
    customer_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    customer_code VARCHAR(50) NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    tax_id VARCHAR(50),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    payment_terms INTEGER DEFAULT 30, -- days
    credit_limit DECIMAL(20,4),
    default_currency CHAR(3) DEFAULT 'AED',
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(tenant_id, customer_code)
);

CREATE INDEX idx_customers_tenant ON customers(tenant_id);
CREATE INDEX idx_customers_name ON customers USING gin(customer_name gin_trgm_ops);

-- AR Invoices
CREATE TABLE IF NOT EXISTS ar_invoices (
    invoice_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    customer_id UUID NOT NULL REFERENCES customers(customer_id),
    invoice_number VARCHAR(100) NOT NULL,
    invoice_date DATE NOT NULL,
    due_date DATE NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'AED',
    subtotal DECIMAL(20,4) NOT NULL,
    tax_amount DECIMAL(20,4) DEFAULT 0,
    total_amount DECIMAL(20,4) NOT NULL,
    amount_paid DECIMAL(20,4) DEFAULT 0,
    amount_outstanding DECIMAL(20,4) NOT NULL,
    status VARCHAR(20) DEFAULT 'draft', -- draft, sent, overdue, paid, cancelled
    payment_status VARCHAR(20) DEFAULT 'unpaid', -- unpaid, partial, paid
    sent_at TIMESTAMPTZ,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(tenant_id, invoice_number)
);

CREATE INDEX idx_ar_invoices_tenant ON ar_invoices(tenant_id);
CREATE INDEX idx_ar_invoices_customer ON ar_invoices(customer_id);
CREATE INDEX idx_ar_invoices_date ON ar_invoices(invoice_date);
CREATE INDEX idx_ar_invoices_due ON ar_invoices(due_date);
CREATE INDEX idx_ar_invoices_status ON ar_invoices(status, payment_status);

-- AR Invoice Lines
CREATE TABLE IF NOT EXISTS ar_invoice_lines (
    line_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES ar_invoices(invoice_id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    line_number INTEGER NOT NULL,
    description TEXT NOT NULL,
    quantity DECIMAL(12,4) DEFAULT 1,
    unit_price DECIMAL(20,4) NOT NULL,
    line_amount DECIMAL(20,4) NOT NULL,
    tax_rate DECIMAL(5,4) DEFAULT 0.05,
    tax_amount DECIMAL(20,4) DEFAULT 0,
    gl_account_id UUID REFERENCES chart_of_accounts(account_id),
    dimension_1 VARCHAR(50),
    dimension_2 VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(invoice_id, line_number)
);

CREATE INDEX idx_ar_lines_invoice ON ar_invoice_lines(invoice_id);
CREATE INDEX idx_ar_lines_account ON ar_invoice_lines(gl_account_id);

-- AR Aging Projection
CREATE TABLE IF NOT EXISTS ar_aging (
    aging_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    customer_id UUID NOT NULL REFERENCES customers(customer_id),
    invoice_id UUID NOT NULL REFERENCES ar_invoices(invoice_id),
    currency CHAR(3) NOT NULL,
    total_outstanding DECIMAL(20,4) NOT NULL,
    current_amount DECIMAL(20,4) DEFAULT 0, -- 0-30 days
    bucket_30 DECIMAL(20,4) DEFAULT 0,      -- 31-60 days
    bucket_60 DECIMAL(20,4) DEFAULT 0,      -- 61-90 days
    bucket_90 DECIMAL(20,4) DEFAULT 0,      -- 91-120 days
    bucket_120_plus DECIMAL(20,4) DEFAULT 0, -- 120+ days
    as_of_date DATE NOT NULL,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, invoice_id, as_of_date)
);

CREATE INDEX idx_ar_aging_tenant ON ar_aging(tenant_id);
CREATE INDEX idx_ar_aging_customer ON ar_aging(customer_id);
CREATE INDEX idx_ar_aging_date ON ar_aging(as_of_date);

-- ============================================
-- TREASURY & CASH MANAGEMENT
-- ============================================

-- Bank Accounts
CREATE TABLE IF NOT EXISTS bank_accounts (
    bank_account_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    account_code VARCHAR(50) NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    bank_name VARCHAR(255) NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    iban VARCHAR(50),
    swift_code VARCHAR(20),
    currency CHAR(3) NOT NULL DEFAULT 'AED',
    account_type VARCHAR(50) DEFAULT 'checking', -- checking, savings, investment
    gl_account_id UUID REFERENCES chart_of_accounts(account_id),
    current_balance DECIMAL(20,4) DEFAULT 0,
    available_balance DECIMAL(20,4) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active',
    last_reconciled_date DATE,
    last_reconciled_balance DECIMAL(20,4),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(tenant_id, account_code)
);

CREATE INDEX idx_bank_accounts_tenant ON bank_accounts(tenant_id);
CREATE INDEX idx_bank_accounts_gl ON bank_accounts(gl_account_id);

-- Bank Transactions
CREATE TABLE IF NOT EXISTS bank_transactions (
    transaction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    bank_account_id UUID NOT NULL REFERENCES bank_accounts(bank_account_id),
    transaction_date DATE NOT NULL,
    value_date DATE NOT NULL,
    description TEXT,
    reference VARCHAR(100),
    debit_amount DECIMAL(20,4) DEFAULT 0,
    credit_amount DECIMAL(20,4) DEFAULT 0,
    balance DECIMAL(20,4),
    currency CHAR(3) NOT NULL,
    reconciliation_status VARCHAR(20) DEFAULT 'unreconciled', -- unreconciled, matched, reconciled
    matched_journal_entry_id UUID,
    ai_match_confidence DECIMAL(5,4),
    ai_suggested_matches JSONB,
    reconciled_by UUID,
    reconciled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB
);

CREATE INDEX idx_bank_trans_account ON bank_transactions(bank_account_id);
CREATE INDEX idx_bank_trans_date ON bank_transactions(transaction_date);
CREATE INDEX idx_bank_trans_status ON bank_transactions(reconciliation_status);

-- Cash Flow Forecast Projection
CREATE TABLE IF NOT EXISTS cash_flow_forecast (
    forecast_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    forecast_date DATE NOT NULL,
    forecast_type VARCHAR(50) NOT NULL, -- daily, weekly, monthly
    currency CHAR(3) NOT NULL DEFAULT 'AED',
    opening_balance DECIMAL(20,4) NOT NULL,
    forecasted_inflows DECIMAL(20,4) DEFAULT 0,
    forecasted_outflows DECIMAL(20,4) DEFAULT 0,
    forecasted_closing_balance DECIMAL(20,4) NOT NULL,
    actual_closing_balance DECIMAL(20,4),
    variance DECIMAL(20,4),
    confidence_interval_low DECIMAL(20,4),
    confidence_interval_high DECIMAL(20,4),
    ml_model_version VARCHAR(50),
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    as_of_date DATE NOT NULL,
    metadata JSONB,
    UNIQUE(tenant_id, forecast_date, forecast_type, as_of_date)
);

CREATE INDEX idx_cash_forecast_tenant ON cash_flow_forecast(tenant_id);
CREATE INDEX idx_cash_forecast_date ON cash_flow_forecast(forecast_date);

-- ============================================
-- FP&A - FINANCIAL PLANNING & ANALYSIS
-- ============================================

-- Budgets
CREATE TABLE IF NOT EXISTS budgets (
    budget_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    budget_name VARCHAR(255) NOT NULL,
    budget_type VARCHAR(50) NOT NULL, -- annual, quarterly, rolling
    fiscal_year INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'AED',
    status VARCHAR(20) DEFAULT 'draft', -- draft, submitted, approved, active, closed
    version INTEGER DEFAULT 1,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(tenant_id, budget_name, fiscal_year, version)
);

CREATE INDEX idx_budgets_tenant ON budgets(tenant_id);
CREATE INDEX idx_budgets_year ON budgets(fiscal_year);

-- Budget Lines
CREATE TABLE IF NOT EXISTS budget_lines (
    budget_line_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    budget_id UUID NOT NULL REFERENCES budgets(budget_id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    account_id UUID NOT NULL REFERENCES chart_of_accounts(account_id),
    fiscal_period INTEGER NOT NULL,
    budgeted_amount DECIMAL(20,4) NOT NULL,
    dimension_1 VARCHAR(50),
    dimension_2 VARCHAR(50),
    dimension_3 VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB,
    UNIQUE(budget_id, account_id, fiscal_period, dimension_1, dimension_2, dimension_3)
);

CREATE INDEX idx_budget_lines_budget ON budget_lines(budget_id);
CREATE INDEX idx_budget_lines_account ON budget_lines(account_id);

-- Variance Analysis (Actual vs Budget)
CREATE MATERIALIZED VIEW variance_analysis AS
SELECT
    b.tenant_id,
    b.budget_id,
    bl.account_id,
    bl.fiscal_period,
    bl.budgeted_amount,
    COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0) as actual_amount,
    bl.budgeted_amount - COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0) as variance_amount,
    CASE
        WHEN bl.budgeted_amount != 0 THEN
            ((bl.budgeted_amount - COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0)) / bl.budgeted_amount) * 100
        ELSE 0
    END as variance_percent
FROM budget_lines bl
JOIN budgets b ON bl.budget_id = b.budget_id
LEFT JOIN journal_entry_lines jel ON bl.account_id = jel.account_id
    AND jel.tenant_id = bl.tenant_id
LEFT JOIN journal_entries je ON jel.entry_id = je.entry_id
    AND EXTRACT(MONTH FROM je.entry_date) = bl.fiscal_period
GROUP BY b.tenant_id, b.budget_id, bl.account_id, bl.fiscal_period, bl.budgeted_amount;

CREATE INDEX idx_variance_tenant ON variance_analysis(tenant_id);

-- ============================================
-- AUDIT & COMPLIANCE
-- ============================================

-- Audit Trail
CREATE TABLE IF NOT EXISTS audit_trail (
    audit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    user_id UUID,
    action VARCHAR(100) NOT NULL, -- create, update, delete, approve, post, etc.
    entity_type VARCHAR(100) NOT NULL, -- invoice, journal_entry, payment, etc.
    entity_id UUID NOT NULL,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB
) PARTITION BY RANGE (timestamp);

-- Create audit trail partitions
CREATE TABLE audit_trail_2024 PARTITION OF audit_trail
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE audit_trail_2025 PARTITION OF audit_trail
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE INDEX idx_audit_tenant ON audit_trail(tenant_id);
CREATE INDEX idx_audit_entity ON audit_trail(entity_type, entity_id);
CREATE INDEX idx_audit_user ON audit_trail(user_id);
CREATE INDEX idx_audit_timestamp ON audit_trail(timestamp DESC);

-- Approval Workflows
CREATE TABLE IF NOT EXISTS approval_workflows (
    workflow_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,
    current_step INTEGER DEFAULT 1,
    total_steps INTEGER NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected, cancelled
    initiated_by UUID,
    initiated_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    metadata JSONB
);

CREATE INDEX idx_approval_tenant ON approval_workflows(tenant_id);
CREATE INDEX idx_approval_entity ON approval_workflows(entity_type, entity_id);
CREATE INDEX idx_approval_status ON approval_workflows(status);

-- Approval Steps
CREATE TABLE IF NOT EXISTS approval_steps (
    step_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_id UUID NOT NULL REFERENCES approval_workflows(workflow_id) ON DELETE CASCADE,
    step_number INTEGER NOT NULL,
    approver_id UUID NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected
    decision_date TIMESTAMPTZ,
    comments TEXT,
    metadata JSONB,
    UNIQUE(workflow_id, step_number)
);

CREATE INDEX idx_approval_steps_workflow ON approval_steps(workflow_id);
CREATE INDEX idx_approval_steps_approver ON approval_steps(approver_id);

-- ============================================
-- AI METADATA & TRAINING DATA
-- ============================================

-- AI Training Feedback
CREATE TABLE IF NOT EXISTS ai_training_feedback (
    feedback_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    input_data JSONB NOT NULL,
    predicted_output JSONB NOT NULL,
    actual_output JSONB,
    is_correct BOOLEAN,
    confidence_score DECIMAL(5,4),
    user_id UUID,
    feedback_date TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB
);

CREATE INDEX idx_ai_feedback_model ON ai_training_feedback(model_name, model_version);
CREATE INDEX idx_ai_feedback_tenant ON ai_training_feedback(tenant_id);

-- Anomaly Detection Results
CREATE TABLE IF NOT EXISTS anomaly_detections (
    anomaly_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID NOT NULL,
    anomaly_type VARCHAR(100) NOT NULL, -- duplicate, unusual_amount, pattern_deviation, fraud_risk
    anomaly_score DECIMAL(5,4) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'open', -- open, investigating, false_positive, confirmed, resolved
    detected_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by UUID,
    metadata JSONB
);

CREATE INDEX idx_anomaly_tenant ON anomaly_detections(tenant_id);
CREATE INDEX idx_anomaly_entity ON anomaly_detections(entity_type, entity_id);
CREATE INDEX idx_anomaly_status ON anomaly_detections(status);
CREATE INDEX idx_anomaly_score ON anomaly_detections(anomaly_score DESC);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Function: Update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update_updated_at trigger to relevant tables
CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_coa_updated_at BEFORE UPDATE ON chart_of_accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vendors_updated_at BEFORE UPDATE ON vendors
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function: Calculate event checksum
CREATE OR REPLACE FUNCTION calculate_event_checksum()
RETURNS TRIGGER AS $$
BEGIN
    NEW.checksum = encode(digest(
        NEW.aggregate_id::text ||
        NEW.event_type ||
        NEW.event_data::text ||
        NEW.timestamp::text,
        'sha256'
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER event_store_checksum BEFORE INSERT ON event_store
    FOR EACH ROW EXECUTE FUNCTION calculate_event_checksum();

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

-- Create application role
CREATE ROLE airp_app WITH LOGIN PASSWORD 'airp_app_secure_2024';

-- Grant necessary permissions
GRANT CONNECT ON DATABASE airp_master TO airp_app;
GRANT USAGE ON SCHEMA public TO airp_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO airp_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO airp_app;

-- ============================================
-- ANALYTICS & REPORTING VIEWS
-- ============================================

-- Income Statement View
CREATE OR REPLACE VIEW income_statement AS
SELECT
    je.tenant_id,
    EXTRACT(YEAR FROM je.entry_date) as fiscal_year,
    EXTRACT(MONTH FROM je.entry_date) as fiscal_period,
    coa.account_type,
    coa.account_code,
    coa.account_name,
    SUM(jel.debit_amount) as total_debit,
    SUM(jel.credit_amount) as total_credit,
    CASE
        WHEN coa.account_type = 'Revenue' THEN SUM(jel.credit_amount - jel.debit_amount)
        WHEN coa.account_type = 'Expense' THEN SUM(jel.debit_amount - jel.credit_amount)
        ELSE 0
    END as net_amount
FROM journal_entries je
JOIN journal_entry_lines jel ON je.entry_id = jel.entry_id
JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
WHERE je.status = 'posted'
    AND coa.account_type IN ('Revenue', 'Expense')
GROUP BY je.tenant_id, fiscal_year, fiscal_period, coa.account_type, coa.account_code, coa.account_name;

-- Balance Sheet View
CREATE OR REPLACE VIEW balance_sheet AS
SELECT
    je.tenant_id,
    EXTRACT(YEAR FROM je.entry_date) as fiscal_year,
    coa.account_type,
    coa.account_code,
    coa.account_name,
    SUM(jel.debit_amount - jel.credit_amount) as balance
FROM journal_entries je
JOIN journal_entry_lines jel ON je.entry_id = jel.entry_id
JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
WHERE je.status = 'posted'
    AND coa.account_type IN ('Asset', 'Liability', 'Equity')
GROUP BY je.tenant_id, fiscal_year, coa.account_type, coa.account_code, coa.account_name;

-- Cash Position View
CREATE OR REPLACE VIEW cash_position AS
SELECT
    ba.tenant_id,
    ba.bank_account_id,
    ba.account_name,
    ba.currency,
    ba.current_balance,
    ba.available_balance,
    SUM(CASE WHEN bt.transaction_date >= CURRENT_DATE AND bt.credit_amount > 0
        THEN bt.credit_amount ELSE 0 END) as todays_inflows,
    SUM(CASE WHEN bt.transaction_date >= CURRENT_DATE AND bt.debit_amount > 0
        THEN bt.debit_amount ELSE 0 END) as todays_outflows
FROM bank_accounts ba
LEFT JOIN bank_transactions bt ON ba.bank_account_id = bt.bank_account_id
WHERE ba.status = 'active'
GROUP BY ba.tenant_id, ba.bank_account_id, ba.account_name, ba.currency,
         ba.current_balance, ba.available_balance;

-- ============================================
-- COMMENTS
-- ============================================

COMMENT ON TABLE event_store IS 'Immutable event store - source of truth for all transactions';
COMMENT ON TABLE journal_entries IS 'Projection of journal entries from event store';
COMMENT ON TABLE gl_balances IS 'Real-time account balances projection';
COMMENT ON TABLE ap_invoices IS 'Accounts Payable invoices';
COMMENT ON TABLE ar_invoices IS 'Accounts Receivable invoices';
COMMENT ON TABLE bank_transactions IS 'Bank statement transactions for reconciliation';
COMMENT ON TABLE cash_flow_forecast IS 'AI-generated cash flow forecasts';
COMMENT ON TABLE audit_trail IS 'Complete audit trail of all system actions';
COMMENT ON TABLE ai_training_feedback IS 'User feedback for AI model training and improvement';

-- Schema creation complete
SELECT 'AIRP v2.0 Database Schema Created Successfully' as status;
