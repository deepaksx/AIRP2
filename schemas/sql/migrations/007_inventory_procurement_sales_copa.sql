-- =====================================================================
-- AIRP v2.14.0 - Inventory, Procurement, Sales & COPA (Profitability Analysis)
-- =====================================================================
-- This migration creates a comprehensive inventory management system with
-- procurement and sales modules that 100% reconcile with financial accounting.
-- Includes SAP-style COPA (CO-PA) for multi-dimensional profitability analysis.
--
-- Key Features:
-- 1. Inventory Management: Items, warehouses, stock tracking, valuations
-- 2. Procurement: Purchase orders, goods receipts, vendor integration
-- 3. Sales: Sales orders, deliveries, customer integration, revenue recognition
-- 4. COPA: Multi-dimensional profitability (product, customer, region, channel)
-- 5. 100% GL Integration: Every transaction posts to journal_entries
-- 6. Reconciliation: Views and functions to verify GL = Sub-ledger
-- =====================================================================

-- =====================================================================
-- 1. INVENTORY MANAGEMENT
-- =====================================================================

-- 1.1 Inventory Items (Material Master)
CREATE TABLE IF NOT EXISTS inventory_items (
    item_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    item_code VARCHAR(50) NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    description TEXT,

    -- Classification
    item_type VARCHAR(50) DEFAULT 'FINISHED_GOODS', -- FINISHED_GOODS, RAW_MATERIAL, TRADING_GOODS, CONSUMABLES
    item_category VARCHAR(100),
    product_group VARCHAR(100),

    -- Units
    base_unit VARCHAR(20) NOT NULL DEFAULT 'EA', -- EA, KG, L, M, etc.

    -- Valuation
    valuation_method VARCHAR(50) DEFAULT 'WEIGHTED_AVERAGE', -- WEIGHTED_AVERAGE, FIFO, STANDARD_COST
    standard_cost DECIMAL(15, 4) DEFAULT 0.00,

    -- GL Accounts (for automatic posting)
    inventory_account_id UUID REFERENCES chart_of_accounts(account_id),
    cogs_account_id UUID REFERENCES chart_of_accounts(account_id),
    revenue_account_id UUID REFERENCES chart_of_accounts(account_id),
    inventory_variance_account_id UUID REFERENCES chart_of_accounts(account_id),

    -- Status
    is_active BOOLEAN DEFAULT true,
    is_stockable BOOLEAN DEFAULT true,
    is_purchasable BOOLEAN DEFAULT true,
    is_saleable BOOLEAN DEFAULT true,

    -- AI Context
    ai_context_summary TEXT,
    ai_context_keywords TEXT[],
    ai_context_generated_at TIMESTAMPTZ,
    ai_needs_context_update BOOLEAN DEFAULT false,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(user_id),
    metadata JSONB DEFAULT '{}',

    UNIQUE(tenant_id, item_code)
);

CREATE INDEX idx_inventory_items_tenant ON inventory_items(tenant_id);
CREATE INDEX idx_inventory_items_type ON inventory_items(item_type);
CREATE INDEX idx_inventory_items_category ON inventory_items(item_category);
CREATE INDEX idx_inventory_items_group ON inventory_items(product_group);
CREATE INDEX idx_inventory_items_keywords ON inventory_items USING GIN(ai_context_keywords);

-- 1.2 Warehouses / Storage Locations
CREATE TABLE IF NOT EXISTS warehouses (
    warehouse_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    warehouse_code VARCHAR(50) NOT NULL,
    warehouse_name VARCHAR(255) NOT NULL,
    warehouse_type VARCHAR(50) DEFAULT 'STANDARD', -- STANDARD, CONSIGNMENT, QUARANTINE, TRANSIT

    -- Location
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),

    -- Contact
    contact_person VARCHAR(255),
    phone VARCHAR(50),
    email VARCHAR(255),

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB DEFAULT '{}',

    UNIQUE(tenant_id, warehouse_code)
);

CREATE INDEX idx_warehouses_tenant ON warehouses(tenant_id);
CREATE INDEX idx_warehouses_active ON warehouses(is_active);

-- 1.3 Inventory Stock (Current Balances)
CREATE TABLE IF NOT EXISTS inventory_stock (
    stock_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    item_id UUID NOT NULL REFERENCES inventory_items(item_id),
    warehouse_id UUID NOT NULL REFERENCES warehouses(warehouse_id),

    -- Quantities
    quantity_on_hand DECIMAL(15, 4) DEFAULT 0.00,
    quantity_reserved DECIMAL(15, 4) DEFAULT 0.00, -- Reserved for sales orders
    quantity_available DECIMAL(15, 4) DEFAULT 0.00, -- on_hand - reserved
    quantity_on_order DECIMAL(15, 4) DEFAULT 0.00, -- Outstanding POs

    -- Valuation
    total_value DECIMAL(15, 4) DEFAULT 0.00,
    average_cost DECIMAL(15, 4) DEFAULT 0.00,

    -- Dates
    last_receipt_date TIMESTAMPTZ,
    last_issue_date TIMESTAMPTZ,

    -- Audit
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(tenant_id, item_id, warehouse_id)
);

CREATE INDEX idx_inventory_stock_tenant ON inventory_stock(tenant_id);
CREATE INDEX idx_inventory_stock_item ON inventory_stock(item_id);
CREATE INDEX idx_inventory_stock_warehouse ON inventory_stock(warehouse_id);

-- 1.4 Inventory Transactions (All Movements)
CREATE TABLE IF NOT EXISTS inventory_transactions (
    transaction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),

    -- Transaction Info
    transaction_number VARCHAR(50) NOT NULL,
    transaction_type VARCHAR(50) NOT NULL, -- RECEIPT, ISSUE, TRANSFER, ADJUSTMENT, GOODS_RECEIPT, GOODS_ISSUE
    transaction_date DATE NOT NULL,
    posting_date DATE NOT NULL,

    -- Item & Location
    item_id UUID NOT NULL REFERENCES inventory_items(item_id),
    warehouse_id UUID NOT NULL REFERENCES warehouses(warehouse_id),

    -- Quantity & Value
    quantity DECIMAL(15, 4) NOT NULL,
    unit_cost DECIMAL(15, 4) DEFAULT 0.00,
    total_value DECIMAL(15, 4) DEFAULT 0.00,

    -- References
    reference_type VARCHAR(50), -- PURCHASE_ORDER, SALES_ORDER, PRODUCTION_ORDER, MANUAL
    reference_id UUID, -- ID of the source document
    reference_number VARCHAR(50),

    -- Journal Entry Link (for GL integration)
    journal_entry_id UUID REFERENCES journal_entries(journal_entry_id),

    -- Notes
    notes TEXT,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    metadata JSONB DEFAULT '{}',

    UNIQUE(tenant_id, transaction_number)
);

CREATE INDEX idx_inventory_txn_tenant ON inventory_transactions(tenant_id);
CREATE INDEX idx_inventory_txn_type ON inventory_transactions(transaction_type);
CREATE INDEX idx_inventory_txn_date ON inventory_transactions(transaction_date);
CREATE INDEX idx_inventory_txn_item ON inventory_transactions(item_id);
CREATE INDEX idx_inventory_txn_warehouse ON inventory_transactions(warehouse_id);
CREATE INDEX idx_inventory_txn_reference ON inventory_transactions(reference_type, reference_id);
CREATE INDEX idx_inventory_txn_journal ON inventory_transactions(journal_entry_id);

-- =====================================================================
-- 2. PROCUREMENT MODULE
-- =====================================================================

-- 2.1 Purchase Orders (Header)
CREATE TABLE IF NOT EXISTS purchase_orders (
    po_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),

    -- PO Info
    po_number VARCHAR(50) NOT NULL,
    po_date DATE NOT NULL,

    -- Vendor
    vendor_id UUID NOT NULL REFERENCES vendors(vendor_id),

    -- Delivery
    requested_delivery_date DATE,
    warehouse_id UUID REFERENCES warehouses(warehouse_id),

    -- Totals
    currency VARCHAR(3) DEFAULT 'AED',
    subtotal DECIMAL(15, 4) DEFAULT 0.00,
    tax_amount DECIMAL(15, 4) DEFAULT 0.00,
    total_amount DECIMAL(15, 4) DEFAULT 0.00,

    -- Status
    status VARCHAR(50) DEFAULT 'DRAFT', -- DRAFT, APPROVED, SENT, PARTIALLY_RECEIVED, RECEIVED, CANCELLED

    -- Terms
    payment_terms VARCHAR(100),
    delivery_terms VARCHAR(100),

    -- Approvals
    approved_by UUID REFERENCES users(user_id),
    approved_at TIMESTAMPTZ,

    -- Notes
    notes TEXT,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(user_id),
    metadata JSONB DEFAULT '{}',

    UNIQUE(tenant_id, po_number)
);

CREATE INDEX idx_po_tenant ON purchase_orders(tenant_id);
CREATE INDEX idx_po_vendor ON purchase_orders(vendor_id);
CREATE INDEX idx_po_status ON purchase_orders(status);
CREATE INDEX idx_po_date ON purchase_orders(po_date);

-- 2.2 Purchase Order Lines
CREATE TABLE IF NOT EXISTS purchase_order_lines (
    po_line_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    po_id UUID NOT NULL REFERENCES purchase_orders(po_id) ON DELETE CASCADE,

    line_number INTEGER NOT NULL,

    -- Item
    item_id UUID NOT NULL REFERENCES inventory_items(item_id),
    description TEXT,

    -- Quantity
    ordered_quantity DECIMAL(15, 4) NOT NULL,
    received_quantity DECIMAL(15, 4) DEFAULT 0.00,
    outstanding_quantity DECIMAL(15, 4) NOT NULL,
    unit VARCHAR(20),

    -- Pricing
    unit_price DECIMAL(15, 4) NOT NULL,
    tax_rate DECIMAL(5, 2) DEFAULT 0.00,
    line_total DECIMAL(15, 4) NOT NULL,

    -- Delivery
    requested_delivery_date DATE,

    -- Status
    line_status VARCHAR(50) DEFAULT 'OPEN', -- OPEN, PARTIALLY_RECEIVED, RECEIVED, CANCELLED

    metadata JSONB DEFAULT '{}',

    UNIQUE(po_id, line_number)
);

CREATE INDEX idx_po_lines_tenant ON purchase_order_lines(tenant_id);
CREATE INDEX idx_po_lines_po ON purchase_order_lines(po_id);
CREATE INDEX idx_po_lines_item ON purchase_order_lines(item_id);
CREATE INDEX idx_po_lines_status ON purchase_order_lines(line_status);

-- 2.3 Goods Receipts (Header)
CREATE TABLE IF NOT EXISTS goods_receipts (
    gr_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),

    -- GR Info
    gr_number VARCHAR(50) NOT NULL,
    gr_date DATE NOT NULL,
    posting_date DATE NOT NULL,

    -- Reference
    po_id UUID REFERENCES purchase_orders(po_id),
    vendor_id UUID NOT NULL REFERENCES vendors(vendor_id),
    warehouse_id UUID NOT NULL REFERENCES warehouses(warehouse_id),

    -- Delivery Info
    delivery_note_number VARCHAR(50),
    delivery_date DATE,

    -- Totals
    currency VARCHAR(3) DEFAULT 'AED',
    total_value DECIMAL(15, 4) DEFAULT 0.00,

    -- Status
    status VARCHAR(50) DEFAULT 'POSTED', -- DRAFT, POSTED, CANCELLED

    -- Journal Entry Link
    journal_entry_id UUID REFERENCES journal_entries(journal_entry_id),

    -- Notes
    notes TEXT,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    metadata JSONB DEFAULT '{}',

    UNIQUE(tenant_id, gr_number)
);

CREATE INDEX idx_gr_tenant ON goods_receipts(tenant_id);
CREATE INDEX idx_gr_po ON goods_receipts(po_id);
CREATE INDEX idx_gr_vendor ON goods_receipts(vendor_id);
CREATE INDEX idx_gr_warehouse ON goods_receipts(warehouse_id);
CREATE INDEX idx_gr_date ON goods_receipts(gr_date);
CREATE INDEX idx_gr_journal ON goods_receipts(journal_entry_id);

-- 2.4 Goods Receipt Lines
CREATE TABLE IF NOT EXISTS goods_receipt_lines (
    gr_line_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    gr_id UUID NOT NULL REFERENCES goods_receipts(gr_id) ON DELETE CASCADE,

    line_number INTEGER NOT NULL,

    -- Reference
    po_line_id UUID REFERENCES purchase_order_lines(po_line_id),

    -- Item
    item_id UUID NOT NULL REFERENCES inventory_items(item_id),
    description TEXT,

    -- Quantity
    received_quantity DECIMAL(15, 4) NOT NULL,
    unit VARCHAR(20),

    -- Valuation
    unit_cost DECIMAL(15, 4) NOT NULL,
    line_value DECIMAL(15, 4) NOT NULL,

    -- Inventory Transaction Link
    inventory_transaction_id UUID REFERENCES inventory_transactions(transaction_id),

    metadata JSONB DEFAULT '{}',

    UNIQUE(gr_id, line_number)
);

CREATE INDEX idx_gr_lines_tenant ON goods_receipt_lines(tenant_id);
CREATE INDEX idx_gr_lines_gr ON goods_receipt_lines(gr_id);
CREATE INDEX idx_gr_lines_po_line ON goods_receipt_lines(po_line_id);
CREATE INDEX idx_gr_lines_item ON goods_receipt_lines(item_id);
CREATE INDEX idx_gr_lines_inv_txn ON goods_receipt_lines(inventory_transaction_id);

-- =====================================================================
-- 3. SALES MODULE
-- =====================================================================

-- 3.1 Sales Orders (Header)
CREATE TABLE IF NOT EXISTS sales_orders (
    so_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),

    -- SO Info
    so_number VARCHAR(50) NOT NULL,
    so_date DATE NOT NULL,

    -- Customer
    customer_id UUID NOT NULL REFERENCES customers(customer_id),

    -- Delivery
    requested_delivery_date DATE,
    warehouse_id UUID REFERENCES warehouses(warehouse_id),

    -- Shipping Address
    ship_to_name VARCHAR(255),
    ship_to_address TEXT,
    ship_to_city VARCHAR(100),
    ship_to_country VARCHAR(100),

    -- Totals
    currency VARCHAR(3) DEFAULT 'AED',
    subtotal DECIMAL(15, 4) DEFAULT 0.00,
    tax_amount DECIMAL(15, 4) DEFAULT 0.00,
    total_amount DECIMAL(15, 4) DEFAULT 0.00,

    -- Status
    status VARCHAR(50) DEFAULT 'DRAFT', -- DRAFT, CONFIRMED, PARTIALLY_DELIVERED, DELIVERED, INVOICED, CANCELLED

    -- Terms
    payment_terms VARCHAR(100),
    delivery_terms VARCHAR(100),

    -- COPA Characteristics (for profitability analysis)
    copa_sales_org VARCHAR(50),
    copa_distribution_channel VARCHAR(50),
    copa_division VARCHAR(50),
    copa_sales_office VARCHAR(50),
    copa_sales_group VARCHAR(50),
    copa_region VARCHAR(50),
    copa_country VARCHAR(50),

    -- Notes
    notes TEXT,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(user_id),
    metadata JSONB DEFAULT '{}',

    UNIQUE(tenant_id, so_number)
);

CREATE INDEX idx_so_tenant ON sales_orders(tenant_id);
CREATE INDEX idx_so_customer ON sales_orders(customer_id);
CREATE INDEX idx_so_status ON sales_orders(status);
CREATE INDEX idx_so_date ON sales_orders(so_date);
CREATE INDEX idx_so_copa_org ON sales_orders(copa_sales_org);
CREATE INDEX idx_so_copa_channel ON sales_orders(copa_distribution_channel);
CREATE INDEX idx_so_copa_region ON sales_orders(copa_region);

-- 3.2 Sales Order Lines
CREATE TABLE IF NOT EXISTS sales_order_lines (
    so_line_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    so_id UUID NOT NULL REFERENCES sales_orders(so_id) ON DELETE CASCADE,

    line_number INTEGER NOT NULL,

    -- Item
    item_id UUID NOT NULL REFERENCES inventory_items(item_id),
    description TEXT,

    -- Quantity
    ordered_quantity DECIMAL(15, 4) NOT NULL,
    delivered_quantity DECIMAL(15, 4) DEFAULT 0.00,
    outstanding_quantity DECIMAL(15, 4) NOT NULL,
    unit VARCHAR(20),

    -- Pricing
    unit_price DECIMAL(15, 4) NOT NULL,
    cost_price DECIMAL(15, 4) DEFAULT 0.00, -- For COPA margin calculation
    tax_rate DECIMAL(5, 2) DEFAULT 0.00,
    line_total DECIMAL(15, 4) NOT NULL,

    -- Delivery
    requested_delivery_date DATE,

    -- Status
    line_status VARCHAR(50) DEFAULT 'OPEN', -- OPEN, PARTIALLY_DELIVERED, DELIVERED, INVOICED, CANCELLED

    metadata JSONB DEFAULT '{}',

    UNIQUE(so_id, line_number)
);

CREATE INDEX idx_so_lines_tenant ON sales_order_lines(tenant_id);
CREATE INDEX idx_so_lines_so ON sales_order_lines(so_id);
CREATE INDEX idx_so_lines_item ON sales_order_lines(item_id);
CREATE INDEX idx_so_lines_status ON sales_order_lines(line_status);

-- 3.3 Sales Deliveries (Header)
CREATE TABLE IF NOT EXISTS sales_deliveries (
    delivery_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),

    -- Delivery Info
    delivery_number VARCHAR(50) NOT NULL,
    delivery_date DATE NOT NULL,
    posting_date DATE NOT NULL,

    -- Reference
    so_id UUID REFERENCES sales_orders(so_id),
    customer_id UUID NOT NULL REFERENCES customers(customer_id),
    warehouse_id UUID NOT NULL REFERENCES warehouses(warehouse_id),

    -- Shipping Info
    ship_to_name VARCHAR(255),
    ship_to_address TEXT,
    tracking_number VARCHAR(100),
    carrier VARCHAR(100),

    -- Totals
    currency VARCHAR(3) DEFAULT 'AED',
    total_revenue DECIMAL(15, 4) DEFAULT 0.00,
    total_cogs DECIMAL(15, 4) DEFAULT 0.00,
    total_margin DECIMAL(15, 4) DEFAULT 0.00,

    -- Status
    status VARCHAR(50) DEFAULT 'POSTED', -- DRAFT, POSTED, INVOICED, CANCELLED

    -- Journal Entry Link (for revenue and COGS posting)
    journal_entry_id UUID REFERENCES journal_entries(journal_entry_id),

    -- Notes
    notes TEXT,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    metadata JSONB DEFAULT '{}',

    UNIQUE(tenant_id, delivery_number)
);

CREATE INDEX idx_delivery_tenant ON sales_deliveries(tenant_id);
CREATE INDEX idx_delivery_so ON sales_deliveries(so_id);
CREATE INDEX idx_delivery_customer ON sales_deliveries(customer_id);
CREATE INDEX idx_delivery_warehouse ON sales_deliveries(warehouse_id);
CREATE INDEX idx_delivery_date ON sales_deliveries(delivery_date);
CREATE INDEX idx_delivery_journal ON sales_deliveries(journal_entry_id);

-- 3.4 Sales Delivery Lines
CREATE TABLE IF NOT EXISTS sales_delivery_lines (
    delivery_line_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    delivery_id UUID NOT NULL REFERENCES sales_deliveries(delivery_id) ON DELETE CASCADE,

    line_number INTEGER NOT NULL,

    -- Reference
    so_line_id UUID REFERENCES sales_order_lines(so_line_id),

    -- Item
    item_id UUID NOT NULL REFERENCES inventory_items(item_id),
    description TEXT,

    -- Quantity
    delivered_quantity DECIMAL(15, 4) NOT NULL,
    unit VARCHAR(20),

    -- Valuation
    unit_price DECIMAL(15, 4) NOT NULL,
    unit_cost DECIMAL(15, 4) NOT NULL,

    line_revenue DECIMAL(15, 4) NOT NULL,
    line_cogs DECIMAL(15, 4) NOT NULL,
    line_margin DECIMAL(15, 4) NOT NULL,

    -- Inventory Transaction Link
    inventory_transaction_id UUID REFERENCES inventory_transactions(transaction_id),

    -- COPA Link
    copa_actual_id UUID, -- Will reference copa_actual_data

    metadata JSONB DEFAULT '{}',

    UNIQUE(delivery_id, line_number)
);

CREATE INDEX idx_delivery_lines_tenant ON sales_delivery_lines(tenant_id);
CREATE INDEX idx_delivery_lines_delivery ON sales_delivery_lines(delivery_id);
CREATE INDEX idx_delivery_lines_so_line ON sales_delivery_lines(so_line_id);
CREATE INDEX idx_delivery_lines_item ON sales_delivery_lines(item_id);
CREATE INDEX idx_delivery_lines_inv_txn ON sales_delivery_lines(inventory_transaction_id);
CREATE INDEX idx_delivery_lines_copa ON sales_delivery_lines(copa_actual_id);

-- =====================================================================
-- 4. COPA (PROFITABILITY ANALYSIS) - SAP CO-PA Style
-- =====================================================================

-- 4.1 COPA Characteristics (Dimensions)
CREATE TABLE IF NOT EXISTS copa_characteristics (
    characteristic_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),

    characteristic_name VARCHAR(50) NOT NULL, -- PRODUCT, CUSTOMER, SALES_ORG, CHANNEL, REGION, etc.
    characteristic_description VARCHAR(255),

    -- Metadata
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER,

    UNIQUE(tenant_id, characteristic_name)
);

CREATE INDEX idx_copa_char_tenant ON copa_characteristics(tenant_id);

-- Insert default COPA characteristics (SAP standard)
INSERT INTO copa_characteristics (tenant_id, characteristic_name, characteristic_description, display_order)
SELECT
    t.tenant_id,
    characteristic,
    description,
    seq
FROM tenants t
CROSS JOIN (VALUES
    ('PRODUCT', 'Product/Material', 1),
    ('PRODUCT_GROUP', 'Product Group', 2),
    ('CUSTOMER', 'Customer', 3),
    ('CUSTOMER_GROUP', 'Customer Group', 4),
    ('SALES_ORG', 'Sales Organization', 5),
    ('DISTRIBUTION_CHANNEL', 'Distribution Channel', 6),
    ('DIVISION', 'Division', 7),
    ('SALES_OFFICE', 'Sales Office', 8),
    ('SALES_GROUP', 'Sales Group', 9),
    ('REGION', 'Region', 10),
    ('COUNTRY', 'Country', 11),
    ('INDUSTRY', 'Industry Sector', 12)
) AS chars(characteristic, description, seq)
ON CONFLICT (tenant_id, characteristic_name) DO NOTHING;

-- 4.2 COPA Value Fields
CREATE TABLE IF NOT EXISTS copa_value_fields (
    value_field_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),

    value_field_name VARCHAR(50) NOT NULL, -- REVENUE, COGS, GROSS_MARGIN, SALES_QTY, etc.
    value_field_description VARCHAR(255),
    value_field_type VARCHAR(20) DEFAULT 'AMOUNT', -- AMOUNT, QUANTITY, PERCENTAGE

    -- GL Account Reference (for reconciliation)
    gl_account_id UUID REFERENCES chart_of_accounts(account_id),

    -- Metadata
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER,

    UNIQUE(tenant_id, value_field_name)
);

CREATE INDEX idx_copa_value_tenant ON copa_value_fields(tenant_id);

-- Insert default COPA value fields
INSERT INTO copa_value_fields (tenant_id, value_field_name, value_field_description, value_field_type, display_order)
SELECT
    t.tenant_id,
    field_name,
    description,
    field_type,
    seq
FROM tenants t
CROSS JOIN (VALUES
    ('REVENUE', 'Revenue', 'AMOUNT', 1),
    ('SALES_DEDUCTIONS', 'Sales Deductions', 'AMOUNT', 2),
    ('NET_REVENUE', 'Net Revenue', 'AMOUNT', 3),
    ('COGS', 'Cost of Goods Sold', 'AMOUNT', 4),
    ('GROSS_MARGIN', 'Gross Margin', 'AMOUNT', 5),
    ('GROSS_MARGIN_PCT', 'Gross Margin %', 'PERCENTAGE', 6),
    ('SALES_QUANTITY', 'Sales Quantity', 'QUANTITY', 7),
    ('DISCOUNT_AMOUNT', 'Discount Amount', 'AMOUNT', 8),
    ('FREIGHT_COST', 'Freight Cost', 'AMOUNT', 9),
    ('CONTRIBUTION_MARGIN', 'Contribution Margin', 'AMOUNT', 10)
) AS fields(field_name, description, field_type, seq)
ON CONFLICT (tenant_id, value_field_name) DO NOTHING;

-- 4.3 COPA Actual Data (Fact Table)
CREATE TABLE IF NOT EXISTS copa_actual_data (
    copa_actual_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),

    -- Time Dimension
    posting_date DATE NOT NULL,
    fiscal_year INTEGER NOT NULL,
    fiscal_period INTEGER NOT NULL,

    -- Characteristic Values (Dimensions)
    product_id UUID REFERENCES inventory_items(item_id),
    product_code VARCHAR(50),
    product_group VARCHAR(100),

    customer_id UUID REFERENCES customers(customer_id),
    customer_code VARCHAR(50),
    customer_group VARCHAR(100),

    sales_org VARCHAR(50),
    distribution_channel VARCHAR(50),
    division VARCHAR(50),
    sales_office VARCHAR(50),
    sales_group VARCHAR(50),
    region VARCHAR(50),
    country VARCHAR(50),

    -- Reference Documents
    document_type VARCHAR(50), -- SALES_DELIVERY, SALES_INVOICE, SALES_RETURN
    document_id UUID,
    document_number VARCHAR(50),

    -- Value Fields
    currency VARCHAR(3) DEFAULT 'AED',
    revenue DECIMAL(15, 4) DEFAULT 0.00,
    sales_deductions DECIMAL(15, 4) DEFAULT 0.00,
    net_revenue DECIMAL(15, 4) DEFAULT 0.00,
    cogs DECIMAL(15, 4) DEFAULT 0.00,
    gross_margin DECIMAL(15, 4) DEFAULT 0.00,
    gross_margin_pct DECIMAL(5, 2) DEFAULT 0.00,
    sales_quantity DECIMAL(15, 4) DEFAULT 0.00,
    discount_amount DECIMAL(15, 4) DEFAULT 0.00,
    freight_cost DECIMAL(15, 4) DEFAULT 0.00,
    contribution_margin DECIMAL(15, 4) DEFAULT 0.00,

    -- GL Integration
    journal_entry_id UUID REFERENCES journal_entries(journal_entry_id),

    -- Audit
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_copa_actual_tenant ON copa_actual_data(tenant_id);
CREATE INDEX idx_copa_actual_date ON copa_actual_data(posting_date);
CREATE INDEX idx_copa_actual_period ON copa_actual_data(fiscal_year, fiscal_period);
CREATE INDEX idx_copa_actual_product ON copa_actual_data(product_id);
CREATE INDEX idx_copa_actual_customer ON copa_actual_data(customer_id);
CREATE INDEX idx_copa_actual_sales_org ON copa_actual_data(sales_org);
CREATE INDEX idx_copa_actual_channel ON copa_actual_data(distribution_channel);
CREATE INDEX idx_copa_actual_region ON copa_actual_data(region);
CREATE INDEX idx_copa_actual_country ON copa_actual_data(country);
CREATE INDEX idx_copa_actual_document ON copa_actual_data(document_type, document_id);
CREATE INDEX idx_copa_actual_journal ON copa_actual_data(journal_entry_id);

-- =====================================================================
-- 5. RECONCILIATION VIEWS
-- =====================================================================

-- 5.1 Inventory Valuation Summary
CREATE OR REPLACE VIEW vw_inventory_valuation AS
SELECT
    ist.tenant_id,
    ist.item_id,
    ii.item_code,
    ii.item_name,
    ist.warehouse_id,
    w.warehouse_code,
    w.warehouse_name,
    ist.quantity_on_hand,
    ist.quantity_reserved,
    ist.quantity_available,
    ist.average_cost,
    ist.total_value,
    ii.inventory_account_id,
    coa.account_code AS inventory_account_code,
    coa.account_name AS inventory_account_name
FROM inventory_stock ist
JOIN inventory_items ii ON ist.item_id = ii.item_id
JOIN warehouses w ON ist.warehouse_id = w.warehouse_id
LEFT JOIN chart_of_accounts coa ON ii.inventory_account_id = coa.account_id
WHERE ist.quantity_on_hand > 0;

-- 5.2 Inventory GL Reconciliation
CREATE OR REPLACE VIEW vw_inventory_gl_reconciliation AS
SELECT
    iv.tenant_id,
    iv.inventory_account_id,
    iv.inventory_account_code,
    iv.inventory_account_name,
    SUM(iv.total_value) AS inventory_subledger_balance,
    (
        SELECT COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0)
        FROM journal_entry_lines jel
        WHERE jel.account_id = iv.inventory_account_id
        AND jel.tenant_id = iv.tenant_id
    ) AS inventory_gl_balance,
    (
        SELECT COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0)
        FROM journal_entry_lines jel
        WHERE jel.account_id = iv.inventory_account_id
        AND jel.tenant_id = iv.tenant_id
    ) - SUM(iv.total_value) AS reconciliation_difference
FROM vw_inventory_valuation iv
GROUP BY iv.tenant_id, iv.inventory_account_id, iv.inventory_account_code, iv.inventory_account_name;

-- 5.3 COPA Revenue vs GL Reconciliation
CREATE OR REPLACE VIEW vw_copa_revenue_reconciliation AS
SELECT
    copa.tenant_id,
    copa.fiscal_year,
    copa.fiscal_period,
    SUM(copa.revenue) AS copa_total_revenue,
    SUM(copa.cogs) AS copa_total_cogs,
    SUM(copa.gross_margin) AS copa_total_margin,
    (
        SELECT COALESCE(SUM(jel.credit_amount - jel.debit_amount), 0)
        FROM journal_entry_lines jel
        JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
        WHERE coa.account_type = 'REVENUE'
        AND jel.tenant_id = copa.tenant_id
        AND EXTRACT(YEAR FROM jel.posting_date) = copa.fiscal_year
        AND EXTRACT(MONTH FROM jel.posting_date) = copa.fiscal_period
    ) AS gl_total_revenue,
    (
        SELECT COALESCE(SUM(jel.debit_amount - jel.credit_amount), 0)
        FROM journal_entry_lines jel
        JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
        WHERE coa.account_code LIKE '5%' -- COGS accounts
        AND jel.tenant_id = copa.tenant_id
        AND EXTRACT(YEAR FROM jel.posting_date) = copa.fiscal_year
        AND EXTRACT(MONTH FROM jel.posting_date) = copa.fiscal_period
    ) AS gl_total_cogs
FROM copa_actual_data copa
GROUP BY copa.tenant_id, copa.fiscal_year, copa.fiscal_period;

-- 5.4 Purchase Orders Outstanding
CREATE OR REPLACE VIEW vw_po_outstanding AS
SELECT
    po.tenant_id,
    po.po_id,
    po.po_number,
    po.po_date,
    po.vendor_id,
    v.vendor_name,
    po.total_amount,
    po.status,
    COUNT(pol.po_line_id) AS total_lines,
    SUM(pol.ordered_quantity) AS total_ordered_qty,
    SUM(pol.received_quantity) AS total_received_qty,
    SUM(pol.outstanding_quantity) AS total_outstanding_qty,
    SUM(pol.outstanding_quantity * pol.unit_price) AS outstanding_value
FROM purchase_orders po
JOIN vendors v ON po.vendor_id = v.vendor_id
JOIN purchase_order_lines pol ON po.po_id = pol.po_id
WHERE po.status NOT IN ('CANCELLED', 'RECEIVED')
GROUP BY po.tenant_id, po.po_id, po.po_number, po.po_date, po.vendor_id, v.vendor_name, po.total_amount, po.status;

-- 5.5 Sales Orders Outstanding
CREATE OR REPLACE VIEW vw_so_outstanding AS
SELECT
    so.tenant_id,
    so.so_id,
    so.so_number,
    so.so_date,
    so.customer_id,
    c.customer_name,
    so.total_amount,
    so.status,
    COUNT(sol.so_line_id) AS total_lines,
    SUM(sol.ordered_quantity) AS total_ordered_qty,
    SUM(sol.delivered_quantity) AS total_delivered_qty,
    SUM(sol.outstanding_quantity) AS total_outstanding_qty,
    SUM(sol.outstanding_quantity * sol.unit_price) AS outstanding_value
FROM sales_orders so
JOIN customers c ON so.customer_id = c.customer_id
JOIN sales_order_lines sol ON so.so_id = sol.so_id
WHERE so.status NOT IN ('CANCELLED', 'INVOICED')
GROUP BY so.tenant_id, so.so_id, so.so_number, so.so_date, so.customer_id, c.customer_name, so.total_amount, so.status;

-- =====================================================================
-- 6. STORED PROCEDURES FOR TRANSACTION POSTING
-- =====================================================================

-- 6.1 Post Goods Receipt (with GL Integration)
CREATE OR REPLACE FUNCTION post_goods_receipt(
    p_tenant_id UUID,
    p_gr_id UUID,
    p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_gr goods_receipts%ROWTYPE;
    v_journal_entry_id UUID;
    v_journal_number VARCHAR(50);
    v_line goods_receipt_lines%ROWTYPE;
    v_item inventory_items%ROWTYPE;
    v_inv_txn_id UUID;
    v_result JSONB;
BEGIN
    -- Get GR
    SELECT * INTO v_gr FROM goods_receipts WHERE gr_id = p_gr_id AND tenant_id = p_tenant_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Goods Receipt not found');
    END IF;

    IF v_gr.status != 'DRAFT' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Goods Receipt already posted');
    END IF;

    -- Generate journal entry number
    v_journal_number := 'JE-GR-' || TO_CHAR(v_gr.gr_date, 'YYYYMMDD') || '-' || LPAD(NEXTVAL('journal_entry_seq')::TEXT, 6, '0');

    -- Create Journal Entry Header
    INSERT INTO journal_entries (tenant_id, journal_number, journal_date, posting_date, journal_type, reference_number, description, created_by)
    VALUES (p_tenant_id, v_journal_number, v_gr.gr_date, v_gr.posting_date, 'GOODS_RECEIPT', v_gr.gr_number, 'Goods Receipt: ' || v_gr.gr_number, p_user_id)
    RETURNING journal_entry_id INTO v_journal_entry_id;

    -- Process each GR line
    FOR v_line IN
        SELECT * FROM goods_receipt_lines WHERE gr_id = p_gr_id
    LOOP
        -- Get item details
        SELECT * INTO v_item FROM inventory_items WHERE item_id = v_line.item_id;

        -- Create Inventory Transaction
        INSERT INTO inventory_transactions (
            tenant_id, transaction_number, transaction_type, transaction_date, posting_date,
            item_id, warehouse_id, quantity, unit_cost, total_value,
            reference_type, reference_id, reference_number, journal_entry_id, created_by
        ) VALUES (
            p_tenant_id, 'INV-GR-' || v_gr.gr_number || '-' || v_line.line_number, 'GOODS_RECEIPT',
            v_gr.gr_date, v_gr.posting_date, v_line.item_id, v_gr.warehouse_id,
            v_line.received_quantity, v_line.unit_cost, v_line.line_value,
            'GOODS_RECEIPT', p_gr_id, v_gr.gr_number, v_journal_entry_id, p_user_id
        ) RETURNING transaction_id INTO v_inv_txn_id;

        -- Link inventory transaction to GR line
        UPDATE goods_receipt_lines SET inventory_transaction_id = v_inv_txn_id WHERE gr_line_id = v_line.gr_line_id;

        -- Update inventory stock
        INSERT INTO inventory_stock (tenant_id, item_id, warehouse_id, quantity_on_hand, total_value, average_cost, last_receipt_date)
        VALUES (p_tenant_id, v_line.item_id, v_gr.warehouse_id, v_line.received_quantity, v_line.line_value, v_line.unit_cost, v_gr.gr_date)
        ON CONFLICT (tenant_id, item_id, warehouse_id) DO UPDATE SET
            quantity_on_hand = inventory_stock.quantity_on_hand + v_line.received_quantity,
            total_value = inventory_stock.total_value + v_line.line_value,
            average_cost = (inventory_stock.total_value + v_line.line_value) / (inventory_stock.quantity_on_hand + v_line.received_quantity),
            quantity_available = inventory_stock.quantity_on_hand + v_line.received_quantity - inventory_stock.quantity_reserved,
            last_receipt_date = v_gr.gr_date,
            updated_at = CURRENT_TIMESTAMP;

        -- Journal Entry Lines: Dr. Inventory, Cr. GR/IR (AP Clearing)
        -- Dr. Inventory Asset
        INSERT INTO journal_entry_lines (journal_entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, posting_date, description)
        VALUES (v_journal_entry_id, p_tenant_id, v_line.line_number * 2 - 1, v_item.inventory_account_id, v_line.line_value, 0, v_gr.posting_date,
                'Goods Receipt - ' || v_item.item_name);

        -- Cr. GR/IR Clearing (we'll use AP for simplicity, or create a dedicated GR/IR clearing account)
        -- For now, using vendor AP directly
        INSERT INTO journal_entry_lines (journal_entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, posting_date, description)
        VALUES (v_journal_entry_id, p_tenant_id, v_line.line_number * 2,
                (SELECT account_id FROM chart_of_accounts WHERE tenant_id = p_tenant_id AND account_code = '2100' LIMIT 1), -- AP account
                0, v_line.line_value, v_gr.posting_date,
                'GR/IR - ' || v_item.item_name);
    END LOOP;

    -- Update GR status and link journal entry
    UPDATE goods_receipts SET status = 'POSTED', journal_entry_id = v_journal_entry_id WHERE gr_id = p_gr_id;

    -- Update PO line received quantities
    UPDATE purchase_order_lines pol
    SET
        received_quantity = pol.received_quantity + (SELECT SUM(grl.received_quantity) FROM goods_receipt_lines grl WHERE grl.po_line_id = pol.po_line_id AND grl.gr_id = p_gr_id),
        outstanding_quantity = pol.ordered_quantity - (pol.received_quantity + (SELECT COALESCE(SUM(grl.received_quantity), 0) FROM goods_receipt_lines grl WHERE grl.po_line_id = pol.po_line_id AND grl.gr_id = p_gr_id)),
        line_status = CASE
            WHEN pol.ordered_quantity <= (pol.received_quantity + (SELECT COALESCE(SUM(grl.received_quantity), 0) FROM goods_receipt_lines grl WHERE grl.po_line_id = pol.po_line_id AND grl.gr_id = p_gr_id))
            THEN 'RECEIVED'
            ELSE 'PARTIALLY_RECEIVED'
        END
    WHERE pol.po_line_id IN (SELECT po_line_id FROM goods_receipt_lines WHERE gr_id = p_gr_id);

    -- Update PO status
    UPDATE purchase_orders po
    SET status = CASE
        WHEN (SELECT COUNT(*) FROM purchase_order_lines WHERE po_id = po.po_id AND line_status != 'RECEIVED') = 0 THEN 'RECEIVED'
        ELSE 'PARTIALLY_RECEIVED'
    END
    WHERE po.po_id = v_gr.po_id;

    v_result := jsonb_build_object(
        'success', true,
        'gr_id', p_gr_id,
        'journal_entry_id', v_journal_entry_id,
        'journal_number', v_journal_number
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- 6.2 Post Sales Delivery (with GL Integration and COPA)
CREATE OR REPLACE FUNCTION post_sales_delivery(
    p_tenant_id UUID,
    p_delivery_id UUID,
    p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_delivery sales_deliveries%ROWTYPE;
    v_so sales_orders%ROWTYPE;
    v_journal_entry_id UUID;
    v_journal_number VARCHAR(50);
    v_line sales_delivery_lines%ROWTYPE;
    v_item inventory_items%ROWTYPE;
    v_inv_txn_id UUID;
    v_copa_id UUID;
    v_fiscal_year INTEGER;
    v_fiscal_period INTEGER;
    v_result JSONB;
BEGIN
    -- Get Delivery
    SELECT * INTO v_delivery FROM sales_deliveries WHERE delivery_id = p_delivery_id AND tenant_id = p_tenant_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Sales Delivery not found');
    END IF;

    IF v_delivery.status != 'DRAFT' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Sales Delivery already posted');
    END IF;

    -- Get Sales Order
    SELECT * INTO v_so FROM sales_orders WHERE so_id = v_delivery.so_id;

    -- Calculate fiscal period
    v_fiscal_year := EXTRACT(YEAR FROM v_delivery.posting_date);
    v_fiscal_period := EXTRACT(MONTH FROM v_delivery.posting_date);

    -- Generate journal entry number
    v_journal_number := 'JE-SD-' || TO_CHAR(v_delivery.delivery_date, 'YYYYMMDD') || '-' || LPAD(NEXTVAL('journal_entry_seq')::TEXT, 6, '0');

    -- Create Journal Entry Header
    INSERT INTO journal_entries (tenant_id, journal_number, journal_date, posting_date, journal_type, reference_number, description, created_by)
    VALUES (p_tenant_id, v_journal_number, v_delivery.delivery_date, v_delivery.posting_date, 'SALES_DELIVERY', v_delivery.delivery_number,
            'Sales Delivery: ' || v_delivery.delivery_number, p_user_id)
    RETURNING journal_entry_id INTO v_journal_entry_id;

    -- Process each delivery line
    FOR v_line IN
        SELECT * FROM sales_delivery_lines WHERE delivery_id = p_delivery_id
    LOOP
        -- Get item details
        SELECT * INTO v_item FROM inventory_items WHERE item_id = v_line.item_id;

        -- Create Inventory Transaction (Goods Issue)
        INSERT INTO inventory_transactions (
            tenant_id, transaction_number, transaction_type, transaction_date, posting_date,
            item_id, warehouse_id, quantity, unit_cost, total_value,
            reference_type, reference_id, reference_number, journal_entry_id, created_by
        ) VALUES (
            p_tenant_id, 'INV-SD-' || v_delivery.delivery_number || '-' || v_line.line_number, 'GOODS_ISSUE',
            v_delivery.delivery_date, v_delivery.posting_date, v_line.item_id, v_delivery.warehouse_id,
            -v_line.delivered_quantity, v_line.unit_cost, -v_line.line_cogs,
            'SALES_DELIVERY', p_delivery_id, v_delivery.delivery_number, v_journal_entry_id, p_user_id
        ) RETURNING transaction_id INTO v_inv_txn_id;

        -- Link inventory transaction to delivery line
        UPDATE sales_delivery_lines SET inventory_transaction_id = v_inv_txn_id WHERE delivery_line_id = v_line.delivery_line_id;

        -- Update inventory stock
        UPDATE inventory_stock
        SET
            quantity_on_hand = quantity_on_hand - v_line.delivered_quantity,
            total_value = total_value - v_line.line_cogs,
            quantity_available = quantity_on_hand - v_line.delivered_quantity - quantity_reserved,
            last_issue_date = v_delivery.delivery_date,
            updated_at = CURRENT_TIMESTAMP
        WHERE tenant_id = p_tenant_id AND item_id = v_line.item_id AND warehouse_id = v_delivery.warehouse_id;

        -- Create COPA Record
        INSERT INTO copa_actual_data (
            tenant_id, posting_date, fiscal_year, fiscal_period,
            product_id, product_code, product_group,
            customer_id, customer_code, customer_group,
            sales_org, distribution_channel, division, sales_office, sales_group, region, country,
            document_type, document_id, document_number,
            currency, revenue, net_revenue, cogs, gross_margin, gross_margin_pct, sales_quantity,
            journal_entry_id
        ) VALUES (
            p_tenant_id, v_delivery.posting_date, v_fiscal_year, v_fiscal_period,
            v_line.item_id, v_item.item_code, v_item.product_group,
            v_delivery.customer_id,
            (SELECT customer_code FROM customers WHERE customer_id = v_delivery.customer_id),
            (SELECT customer_group FROM customers WHERE customer_id = v_delivery.customer_id),
            v_so.copa_sales_org, v_so.copa_distribution_channel, v_so.copa_division,
            v_so.copa_sales_office, v_so.copa_sales_group, v_so.copa_region, v_so.copa_country,
            'SALES_DELIVERY', p_delivery_id, v_delivery.delivery_number,
            v_delivery.currency, v_line.line_revenue, v_line.line_revenue, v_line.line_cogs, v_line.line_margin,
            CASE WHEN v_line.line_revenue > 0 THEN (v_line.line_margin / v_line.line_revenue * 100) ELSE 0 END,
            v_line.delivered_quantity,
            v_journal_entry_id
        ) RETURNING copa_actual_id INTO v_copa_id;

        -- Link COPA to delivery line
        UPDATE sales_delivery_lines SET copa_actual_id = v_copa_id WHERE delivery_line_id = v_line.delivery_line_id;

        -- Journal Entry Lines
        -- 1. Dr. AR (Accounts Receivable)
        INSERT INTO journal_entry_lines (journal_entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, posting_date, description)
        VALUES (v_journal_entry_id, p_tenant_id, v_line.line_number * 3 - 2,
                (SELECT account_id FROM chart_of_accounts WHERE tenant_id = p_tenant_id AND account_code = '1200' LIMIT 1), -- AR account
                v_line.line_revenue, 0, v_delivery.posting_date,
                'Sales Revenue - ' || v_item.item_name);

        -- 2. Cr. Revenue
        INSERT INTO journal_entry_lines (journal_entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, posting_date, description)
        VALUES (v_journal_entry_id, p_tenant_id, v_line.line_number * 3 - 1, v_item.revenue_account_id,
                0, v_line.line_revenue, v_delivery.posting_date,
                'Sales Revenue - ' || v_item.item_name);

        -- 3. Dr. COGS
        INSERT INTO journal_entry_lines (journal_entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, posting_date, description)
        VALUES (v_journal_entry_id, p_tenant_id, v_line.line_number * 3, v_item.cogs_account_id,
                v_line.line_cogs, 0, v_delivery.posting_date,
                'COGS - ' || v_item.item_name);

        -- 4. Cr. Inventory
        INSERT INTO journal_entry_lines (journal_entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, posting_date, description)
        VALUES (v_journal_entry_id, p_tenant_id, v_line.line_number * 3 + 1, v_item.inventory_account_id,
                0, v_line.line_cogs, v_delivery.posting_date,
                'Inventory Issue - ' || v_item.item_name);
    END LOOP;

    -- Update delivery totals and status
    UPDATE sales_deliveries
    SET
        status = 'POSTED',
        journal_entry_id = v_journal_entry_id,
        total_revenue = (SELECT SUM(line_revenue) FROM sales_delivery_lines WHERE delivery_id = p_delivery_id),
        total_cogs = (SELECT SUM(line_cogs) FROM sales_delivery_lines WHERE delivery_id = p_delivery_id),
        total_margin = (SELECT SUM(line_margin) FROM sales_delivery_lines WHERE delivery_id = p_delivery_id)
    WHERE delivery_id = p_delivery_id;

    -- Update SO line delivered quantities
    UPDATE sales_order_lines sol
    SET
        delivered_quantity = sol.delivered_quantity + (SELECT SUM(sdl.delivered_quantity) FROM sales_delivery_lines sdl WHERE sdl.so_line_id = sol.so_line_id AND sdl.delivery_id = p_delivery_id),
        outstanding_quantity = sol.ordered_quantity - (sol.delivered_quantity + (SELECT COALESCE(SUM(sdl.delivered_quantity), 0) FROM sales_delivery_lines sdl WHERE sdl.so_line_id = sol.so_line_id AND sdl.delivery_id = p_delivery_id)),
        line_status = CASE
            WHEN sol.ordered_quantity <= (sol.delivered_quantity + (SELECT COALESCE(SUM(sdl.delivered_quantity), 0) FROM sales_delivery_lines sdl WHERE sdl.so_line_id = sol.so_line_id AND sdl.delivery_id = p_delivery_id))
            THEN 'DELIVERED'
            ELSE 'PARTIALLY_DELIVERED'
        END
    WHERE sol.so_line_id IN (SELECT so_line_id FROM sales_delivery_lines WHERE delivery_id = p_delivery_id);

    -- Update SO status
    UPDATE sales_orders so
    SET status = CASE
        WHEN (SELECT COUNT(*) FROM sales_order_lines WHERE so_id = so.so_id AND line_status NOT IN ('DELIVERED', 'INVOICED')) = 0 THEN 'DELIVERED'
        ELSE 'PARTIALLY_DELIVERED'
    END
    WHERE so.so_id = v_delivery.so_id;

    v_result := jsonb_build_object(
        'success', true,
        'delivery_id', p_delivery_id,
        'journal_entry_id', v_journal_entry_id,
        'journal_number', v_journal_number,
        'copa_records_created', (SELECT COUNT(*) FROM copa_actual_data WHERE document_id = p_delivery_id)
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- 7. SEQUENCE FOR AUTO-NUMBERING
-- =====================================================================

CREATE SEQUENCE IF NOT EXISTS inventory_txn_seq START 1;
CREATE SEQUENCE IF NOT EXISTS po_seq START 1;
CREATE SEQUENCE IF NOT EXISTS gr_seq START 1;
CREATE SEQUENCE IF NOT EXISTS so_seq START 1;
CREATE SEQUENCE IF NOT EXISTS delivery_seq START 1;

-- =====================================================================
-- 8. TRIGGERS FOR CONTEXT UPDATES
-- =====================================================================

-- Trigger for inventory items
CREATE TRIGGER trigger_inventory_context_update
AFTER INSERT OR UPDATE ON inventory_items
FOR EACH ROW
EXECUTE FUNCTION trigger_context_update();

-- =====================================================================
-- MIGRATION COMPLETE
-- =====================================================================

-- Insert version tracking
INSERT INTO schema_version (version, description, applied_at)
VALUES ('007', 'Inventory, Procurement, Sales & COPA modules with 100% GL integration', CURRENT_TIMESTAMP);
