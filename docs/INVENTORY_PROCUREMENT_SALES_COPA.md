# Inventory, Procurement, Sales & COPA Module
## AIRP v2.14.0 - Complete Supply Chain Management with SAP-Style Profitability Analysis

**Date**: 2025-10-23
**Version**: 2.14.0
**Status**: ✅ Production Ready

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Architecture](#architecture)
4. [Database Schema](#database-schema)
5. [API Endpoints](#api-endpoints)
6. [Reconciliation & Integration](#reconciliation--integration)
7. [COPA (Profitability Analysis)](#copa-profitability-analysis)
8. [Frontend Applications](#frontend-applications)
9. [Transaction Flow](#transaction-flow)
10. [Testing](#testing)
11. [Migration Guide](#migration-guide)

---

## 🎯 Overview

The Inventory, Procurement, Sales & COPA module is a comprehensive supply chain management system that provides:

- **Inventory Management**: Complete item master, warehouse management, stock tracking with FIFO/weighted average costing
- **Procurement**: Purchase orders, goods receipts with automatic GL posting
- **Sales**: Sales orders, deliveries with revenue recognition and COGS calculation
- **COPA (CO-PA)**: SAP-style multi-dimensional profitability analysis
- **100% GL Integration**: Every transaction automatically posts to the General Ledger
- **Real-time Reconciliation**: Sub-ledger to GL reconciliation views

### Key Design Principles

1. **Event-Driven Architecture**: All transactions generate events for audit trail
2. **Double-Entry Bookkeeping**: Every inventory movement creates corresponding GL entries
3. **Multi-Dimensional Analysis**: COPA tracks profitability by product, customer, region, sales org, channel, etc.
4. **SAP Compatibility**: Follows SAP CO-PA data model and concepts
5. **Atomic Transactions**: Database functions ensure all-or-nothing posting

---

## ✨ Key Features

### Inventory Management

- ✅ Material master with multiple valuation methods (FIFO, Weighted Average, Standard Cost)
- ✅ Multi-warehouse support with location-specific stock tracking
- ✅ Real-time stock levels (On-Hand, Reserved, Available, On-Order)
- ✅ Automatic cost averaging and inventory valuation
- ✅ Complete transaction history with audit trail
- ✅ Low stock alerts and inventory analytics
- ✅ AI-powered context generation for items

### Procurement

- ✅ Purchase order creation and management
- ✅ Multi-line PO support with item-level tracking
- ✅ Goods receipt against PO with 3-way match
- ✅ Automatic inventory update on goods receipt
- ✅ Vendor integration with AP clearing
- ✅ Outstanding PO tracking and reporting
- ✅ PO status management (Draft → Approved → Received)

### Sales

- ✅ Sales order creation with customer integration
- ✅ Multi-line SO support with delivery tracking
- ✅ Sales delivery with automatic:
  - Revenue recognition (Dr. AR, Cr. Revenue)
  - COGS calculation (Dr. COGS, Cr. Inventory)
  - COPA record creation
- ✅ Outstanding SO tracking
- ✅ Customer profitability analysis
- ✅ Sales analytics and reporting

### COPA (Profitability Analysis)

- ✅ **Multi-Dimensional Analysis** by:
  - Product / Product Group
  - Customer / Customer Group
  - Sales Organization
  - Distribution Channel
  - Division
  - Sales Office / Sales Group
  - Region / Country
  - Industry Sector
- ✅ **Value Fields**:
  - Revenue (Gross, Net, Deductions)
  - Cost of Goods Sold (COGS)
  - Gross Margin (Amount & Percentage)
  - Sales Quantity
  - Discounts & Freight
  - Contribution Margin
- ✅ **Real-Time Updates**: COPA updated simultaneously with sales delivery posting
- ✅ **GL Reconciliation**: Automated reconciliation views verify COPA = GL
- ✅ **Trend Analysis**: Period-over-period profitability tracking
- ✅ **Top-N Reports**: Best/worst performing products, customers, regions

---

## 🏗️ Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Frontend Layer                           │
│  inventory.html  |  procurement.html  |  copa-analysis.html  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              Inventory Service (NestJS)                      │
│  Port: 3009                                                  │
│  ┌─────────────┬───────────────┬────────────┬─────────────┐│
│  │  Inventory  │  Procurement  │   Sales    │    COPA     ││
│  │   Module    │    Module     │   Module   │   Module    ││
│  └─────────────┴───────────────┴────────────┴─────────────┘│
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              PostgreSQL 15 Database                          │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Inventory Tables | Procurement | Sales | COPA | GL      ││
│  │ PL/pgSQL Functions: post_goods_receipt(),              ││
│  │                     post_sales_delivery()              ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### Data Flow: Purchase to Sale

```
1. CREATE PO
   └→ purchase_orders + purchase_order_lines

2. POST GOODS RECEIPT
   └→ goods_receipts + goods_receipt_lines
   └→ inventory_transactions (Receipt)
   └→ inventory_stock (Quantity ↑, Value ↑)
   └→ journal_entries + journal_entry_lines
       Dr. Inventory Asset
       Cr. AP / GR-IR Clearing

3. CREATE SALES ORDER
   └→ sales_orders + sales_order_lines

4. POST SALES DELIVERY
   └→ sales_deliveries + sales_delivery_lines
   └→ inventory_transactions (Issue)
   └→ inventory_stock (Quantity ↓, Value ↓)
   └→ copa_actual_data (Profitability record)
   └→ journal_entries + journal_entry_lines
       Dr. AR (Revenue)
       Cr. Revenue Account
       Dr. COGS Account
       Cr. Inventory Asset
```

---

## 🗄️ Database Schema

### Core Tables

#### Inventory Management

```sql
inventory_items          -- Material master (item code, name, type, cost accounts)
warehouses               -- Storage locations
inventory_stock          -- Current stock levels by item/warehouse
inventory_transactions   -- All movements (receipts, issues, transfers)
```

#### Procurement

```sql
purchase_orders          -- PO header
purchase_order_lines     -- PO line items
goods_receipts           -- GR header
goods_receipt_lines      -- GR line items
```

#### Sales

```sql
sales_orders             -- SO header with COPA characteristics
sales_order_lines        -- SO line items
sales_deliveries         -- Delivery header
sales_delivery_lines     -- Delivery line items with COPA link
```

#### COPA (Profitability Analysis)

```sql
copa_characteristics     -- Dimensions (Product, Customer, Region, etc.)
copa_value_fields        -- Value fields (Revenue, COGS, Margin, etc.)
copa_actual_data         -- Fact table with actual profitability data
```

### Key Reconciliation Views

```sql
vw_inventory_valuation          -- Current inventory value by item/warehouse
vw_inventory_gl_reconciliation  -- Inventory sub-ledger vs GL
vw_copa_revenue_reconciliation  -- COPA revenue/COGS vs GL
vw_po_outstanding               -- Open purchase orders
vw_so_outstanding               -- Open sales orders
```

### Database Functions

#### `post_goods_receipt(tenant_id, gr_id, user_id)`

**Purpose**: Post goods receipt to inventory and GL

**Logic**:
1. Validate GR status = 'DRAFT'
2. Create journal entry header
3. For each GR line:
   - Create inventory transaction (receipt)
   - Update inventory_stock (quantity ↑, value ↑, average cost recalc)
   - Create journal entry lines:
     - Dr. Inventory Asset
     - Cr. AP / GR-IR Clearing
4. Update GR status to 'POSTED'
5. Update PO line received quantities
6. Update PO status (Partially Received / Received)

**Returns**: `{ success: true, journal_entry_id, journal_number }`

#### `post_sales_delivery(tenant_id, delivery_id, user_id)`

**Purpose**: Post sales delivery to inventory, revenue, and COPA

**Logic**:
1. Validate delivery status = 'DRAFT'
2. Create journal entry header
3. For each delivery line:
   - Create inventory transaction (issue)
   - Update inventory_stock (quantity ↓, value ↓)
   - Create COPA record with profitability data
   - Create journal entry lines:
     - Dr. AR (Revenue)
     - Cr. Revenue Account
     - Dr. COGS Account
     - Cr. Inventory Asset
4. Update delivery status to 'POSTED'
5. Update SO line delivered quantities
6. Update SO status (Partially Delivered / Delivered)

**Returns**: `{ success: true, journal_entry_id, journal_number, copa_records_created }`

---

## 🔌 API Endpoints

### Inventory Service (Port 3009)

#### Inventory Management

```
GET    /inventory/items?tenant_id={id}                    # List all items
POST   /inventory/items                                   # Create item
GET    /inventory/items/:id                               # Get item details
PUT    /inventory/items/:id                               # Update item
DELETE /inventory/items/:id                               # Delete item

GET    /inventory/warehouses?tenant_id={id}               # List warehouses
POST   /inventory/warehouses                              # Create warehouse
GET    /inventory/warehouses/:id                          # Get warehouse

GET    /inventory/stock/by-item/:itemId?tenant_id={id}    # Stock by item
GET    /inventory/stock/by-warehouse/:whId?tenant_id={id} # Stock by warehouse

GET    /inventory/valuation?tenant_id={id}                # Inventory valuation
GET    /inventory/reconciliation?tenant_id={id}           # GL reconciliation
GET    /inventory/transactions?tenant_id={id}             # Transaction history
```

#### Procurement

```
GET    /procurement/purchase-orders?tenant_id={id}        # List POs
POST   /procurement/purchase-orders                       # Create PO
GET    /procurement/purchase-orders/:id                   # Get PO with lines
GET    /procurement/purchase-orders/outstanding           # Outstanding POs

POST   /procurement/goods-receipts                        # Create & post GR
POST   /procurement/goods-receipts/:id/post               # Post existing GR
```

#### Sales

```
GET    /sales/sales-orders?tenant_id={id}                 # List SOs
POST   /sales/sales-orders                                # Create SO
GET    /sales/sales-orders/:id                            # Get SO with lines
GET    /sales/sales-orders/outstanding                    # Outstanding SOs

POST   /sales/deliveries                                  # Create & post delivery
POST   /sales/deliveries/:id/post                         # Post existing delivery
```

#### COPA (Profitability Analysis)

```
GET    /copa/profitability?tenant_id={id}&start_date={}&end_date={}&group_by=[]
                                                          # Multi-dimensional profitability

GET    /copa/product-profitability?tenant_id={id}        # Top products by margin
GET    /copa/customer-profitability?tenant_id={id}       # Top customers by margin
GET    /copa/region-profitability?tenant_id={id}         # Regional analysis

GET    /copa/reconciliation?tenant_id={id}&fiscal_year={}&fiscal_period={}
                                                          # COPA vs GL reconciliation

GET    /copa/dashboard?tenant_id={id}                    # Complete COPA dashboard
```

---

## 🔄 Reconciliation & Integration

### 100% GL Integration

Every transaction in the Inventory/Procurement/Sales modules automatically creates corresponding General Ledger entries:

#### Goods Receipt Example

```sql
Dr. Inventory Asset (1500)           10,000 AED
    Cr. Accounts Payable (2100)              10,000 AED
```

#### Sales Delivery Example

```sql
Dr. Accounts Receivable (1200)      15,000 AED
    Cr. Sales Revenue (4000)                 15,000 AED

Dr. Cost of Goods Sold (5000)       10,000 AED
    Cr. Inventory Asset (1500)               10,000 AED
```

### Reconciliation Checks

1. **Inventory Valuation = GL Balance**
   ```sql
   SELECT * FROM vw_inventory_gl_reconciliation
   WHERE reconciliation_difference != 0
   ```

2. **COPA Revenue = GL Revenue**
   ```sql
   SELECT * FROM vw_copa_revenue_reconciliation
   WHERE ABS(copa_total_revenue - gl_total_revenue) > 0.01
   ```

3. **Stock Quantity Verification**
   ```sql
   SELECT
     item_code,
     SUM(CASE WHEN transaction_type IN ('RECEIPT', 'GOODS_RECEIPT') THEN quantity
              WHEN transaction_type IN ('ISSUE', 'GOODS_ISSUE') THEN -quantity
         END) as calculated_quantity,
     (SELECT quantity_on_hand FROM inventory_stock WHERE item_id = it.item_id) as current_stock
   FROM inventory_transactions it
   GROUP BY item_code, item_id
   HAVING calculated_quantity != current_stock
   ```

---

## 📊 COPA (Profitability Analysis)

### SAP CO-PA Concepts

COPA in AIRP follows SAP's Controlling - Profitability Analysis (CO-PA) model:

#### Characteristics (Dimensions)

These define the "slices" by which profitability is analyzed:

| Characteristic | Description | Example Values |
|---------------|-------------|----------------|
| PRODUCT | Material/Product Code | MAT-001, PROD-XYZ |
| PRODUCT_GROUP | Product Category | Electronics, Furniture |
| CUSTOMER | Customer Code | CUST-001 |
| CUSTOMER_GROUP | Customer Segment | Enterprise, SMB, Retail |
| SALES_ORG | Sales Organization | US-WEST, EU-CENTRAL |
| DISTRIBUTION_CHANNEL | Sales Channel | Direct, Retail, Online |
| DIVISION | Business Division | Hardware, Software |
| SALES_OFFICE | Sales Office Location | Dubai, New York |
| SALES_GROUP | Sales Team | Team-A, Team-B |
| REGION | Geographic Region | Middle East, Europe |
| COUNTRY | Country Code | UAE, USA, UK |

#### Value Fields

These are the financial and quantitative measures:

| Value Field | Type | Description |
|------------|------|-------------|
| REVENUE | Amount | Gross revenue |
| SALES_DEDUCTIONS | Amount | Returns, allowances |
| NET_REVENUE | Amount | Revenue - Deductions |
| COGS | Amount | Cost of goods sold |
| GROSS_MARGIN | Amount | Revenue - COGS |
| GROSS_MARGIN_PCT | Percentage | (Margin / Revenue) × 100 |
| SALES_QUANTITY | Quantity | Units sold |
| DISCOUNT_AMOUNT | Amount | Discounts given |
| FREIGHT_COST | Amount | Shipping costs |
| CONTRIBUTION_MARGIN | Amount | Margin after variable costs |

### COPA Data Population

COPA records are created automatically when a sales delivery is posted:

```typescript
// From post_sales_delivery() function
INSERT INTO copa_actual_data (
  tenant_id, posting_date, fiscal_year, fiscal_period,
  product_id, product_code, product_group,
  customer_id, customer_code, customer_group,
  sales_org, distribution_channel, division,
  sales_office, sales_group, region, country,
  document_type, document_id, document_number,
  currency, revenue, net_revenue, cogs, gross_margin,
  gross_margin_pct, sales_quantity,
  journal_entry_id
) VALUES (
  // ... values from sales_delivery and sales_order ...
)
```

### COPA Reports

#### 1. Multi-Dimensional Profitability

```sql
-- Group by Product and Region
SELECT
  product_code, region,
  SUM(revenue) as total_revenue,
  SUM(cogs) as total_cogs,
  SUM(gross_margin) as total_margin,
  (SUM(gross_margin) / SUM(revenue) * 100) as margin_pct
FROM copa_actual_data
WHERE tenant_id = ? AND posting_date BETWEEN ? AND ?
GROUP BY product_code, region
ORDER BY total_margin DESC
```

#### 2. Top Product Profitability

Shows best/worst performing products by gross margin.

#### 3. Customer Profitability

Identifies most/least profitable customers.

#### 4. Regional Analysis

Compares profitability across regions and countries.

#### 5. Trend Analysis

Period-over-period profitability tracking:

```sql
SELECT
  fiscal_year, fiscal_period,
  SUM(revenue) as revenue,
  SUM(gross_margin) as margin,
  (SUM(gross_margin) / SUM(revenue) * 100) as margin_pct
FROM copa_actual_data
GROUP BY fiscal_year, fiscal_period
ORDER BY fiscal_year, fiscal_period
```

---

## 🖥️ Frontend Applications

### 1. Inventory Management (`inventory.html`)

**Features**:
- Material master CRUD
- Warehouse management
- Real-time stock levels display
- Transaction history with filters
- Inventory valuation report
- GL reconciliation view

**Tabs**:
- Items: Browse and manage inventory items
- Stock Levels: Current stock by item/warehouse
- Transactions: Complete movement history
- Valuation: Financial valuation summary
- Warehouses: Warehouse master data

### 2. COPA Analysis (`copa-analysis.html`)

**Features**:
- Interactive profitability dashboard
- Multi-dimensional filtering (date range, dimensions)
- Chart.js visualization of trends
- Top-N reports (products, customers, regions)
- GL reconciliation verification
- Export capabilities

**Tabs**:
- Overview: KPIs, trends, summary matrix
- Product Profitability: Top 20 products by margin
- Customer Profitability: Top 20 customers by margin
- Regional Analysis: Geographic profitability breakdown
- GL Reconciliation: COPA vs GL verification

### 3. Procurement (Future)

- Purchase order creation and approval workflow
- Goods receipt entry with PO reference
- Vendor performance analytics

### 4. Sales (Future)

- Sales order entry with pricing
- Delivery scheduling and execution
- Customer analytics dashboard

---

## 📦 Transaction Flow Examples

### Example 1: Complete Purchase-to-Sale Flow

```typescript
// 1. Create Purchase Order
POST /procurement/purchase-orders
{
  "tenant_id": "...",
  "po_number": "PO-2025-001",
  "po_date": "2025-01-15",
  "vendor_id": "...",
  "warehouse_id": "...",
  "lines": [
    {
      "item_id": "...",
      "ordered_quantity": 100,
      "unit_price": 50.00,
      "line_total": 5000.00
    }
  ],
  "total_amount": 5000.00
}

// 2. Post Goods Receipt
POST /procurement/goods-receipts
{
  "tenant_id": "...",
  "gr_number": "GR-2025-001",
  "gr_date": "2025-01-20",
  "posting_date": "2025-01-20",
  "po_id": "...",
  "vendor_id": "...",
  "warehouse_id": "...",
  "lines": [
    {
      "po_line_id": "...",
      "item_id": "...",
      "received_quantity": 100,
      "unit_cost": 50.00,
      "line_value": 5000.00
    }
  ],
  "total_value": 5000.00
}

// Result:
// - inventory_stock.quantity_on_hand += 100
// - inventory_stock.total_value += 5000
// - journal_entry created: Dr. Inventory 5000, Cr. AP 5000

// 3. Create Sales Order
POST /sales/sales-orders
{
  "tenant_id": "...",
  "so_number": "SO-2025-001",
  "so_date": "2025-02-01",
  "customer_id": "...",
  "warehouse_id": "...",
  "copa_sales_org": "UAE-CENTRAL",
  "copa_region": "Middle East",
  "copa_country": "UAE",
  "lines": [
    {
      "item_id": "...",
      "ordered_quantity": 50,
      "unit_price": 80.00,
      "cost_price": 50.00,
      "line_total": 4000.00
    }
  ],
  "total_amount": 4000.00
}

// 4. Post Sales Delivery
POST /sales/deliveries
{
  "tenant_id": "...",
  "delivery_number": "DEL-2025-001",
  "delivery_date": "2025-02-05",
  "posting_date": "2025-02-05",
  "so_id": "...",
  "customer_id": "...",
  "warehouse_id": "...",
  "lines": [
    {
      "so_line_id": "...",
      "item_id": "...",
      "delivered_quantity": 50,
      "unit_price": 80.00,
      "unit_cost": 50.00,
      "line_revenue": 4000.00,
      "line_cogs": 2500.00,
      "line_margin": 1500.00
    }
  ]
}

// Result:
// - inventory_stock.quantity_on_hand -= 50
// - inventory_stock.total_value -= 2500
// - copa_actual_data record created (revenue: 4000, cogs: 2500, margin: 1500)
// - journal_entry created:
//     Dr. AR 4000, Cr. Revenue 4000
//     Dr. COGS 2500, Cr. Inventory 2500
```

---

## 🧪 Testing

### Manual Testing Steps

1. **Apply Migration**
   ```bash
   psql -U airp_admin -d airp_master -f schemas/sql/migrations/007_inventory_procurement_sales_copa.sql
   ```

2. **Start Inventory Service**
   ```bash
   cd services/inventory-service
   npm install
   npm run start:dev
   ```

3. **Create Test Items**
   - Navigate to `http://localhost:3009/inventory/items`
   - Create sample items with different types

4. **Create Warehouses**
   - Create at least one warehouse for testing

5. **Test Procurement Flow**
   - Create PO via API
   - Post goods receipt
   - Verify inventory stock increased
   - Check GL journal entries created

6. **Test Sales Flow**
   - Create SO via API
   - Post sales delivery
   - Verify inventory stock decreased
   - Check COPA record created
   - Verify GL entries (Revenue & COGS)

7. **Verify Reconciliation**
   - Check inventory valuation reconciliation
   - Verify COPA revenue reconciliation
   - Compare sub-ledger totals with GL

### Automated Tests (Future Enhancement)

```typescript
describe('Inventory Service', () => {
  it('should create item and update stock on goods receipt', async () => {
    // Test implementation
  });

  it('should calculate COGS correctly on sales delivery', async () => {
    // Test implementation
  });

  it('should reconcile inventory value with GL', async () => {
    // Test implementation
  });

  it('should create COPA records on sales posting', async () => {
    // Test implementation
  });
});
```

---

## 🚀 Migration Guide

### Prerequisites

- PostgreSQL 15+ with uuid extension
- Existing AIRP v2.13.x installation
- Backup of production database

### Migration Steps

1. **Backup Database**
   ```bash
   pg_dump -U airp_admin airp_master > backup_$(date +%Y%m%d).sql
   ```

2. **Apply Migration**
   ```bash
   psql -U airp_admin -d airp_master -f schemas/sql/migrations/007_inventory_procurement_sales_copa.sql
   ```

3. **Verify Tables Created**
   ```sql
   SELECT tablename FROM pg_tables
   WHERE schemaname = 'public'
   AND tablename IN (
     'inventory_items', 'warehouses', 'inventory_stock',
     'purchase_orders', 'goods_receipts',
     'sales_orders', 'sales_deliveries',
     'copa_actual_data'
   );
   ```

4. **Install Inventory Service**
   ```bash
   cd services/inventory-service
   npm install
   npm run build
   ```

5. **Update Docker Compose**
   - The docker-compose.yml already includes inventory-service
   - Start services: `docker compose up -d inventory-service`

6. **Deploy Frontend**
   - Copy `inventory.html` and `copa-analysis.html` to web server
   - Update navigation links in main application

7. **Configure Initial Data**
   - Create tenant-specific GL accounts for inventory, COGS, revenue
   - Set up initial warehouses
   - Configure COPA characteristics as needed

8. **Test Integration**
   - Create test items
   - Process test transactions
   - Verify GL posting and reconciliation

### Rollback Procedure

```sql
-- If migration fails, rollback:
DROP TABLE IF EXISTS copa_actual_data CASCADE;
DROP TABLE IF EXISTS copa_value_fields CASCADE;
DROP TABLE IF EXISTS copa_characteristics CASCADE;
DROP TABLE IF EXISTS sales_delivery_lines CASCADE;
DROP TABLE IF EXISTS sales_deliveries CASCADE;
DROP TABLE IF EXISTS sales_order_lines CASCADE;
DROP TABLE IF EXISTS sales_orders CASCADE;
DROP TABLE IF EXISTS goods_receipt_lines CASCADE;
DROP TABLE IF EXISTS goods_receipts CASCADE;
DROP TABLE IF EXISTS purchase_order_lines CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS inventory_transactions CASCADE;
DROP TABLE IF EXISTS inventory_stock CASCADE;
DROP TABLE IF EXISTS warehouses CASCADE;
DROP TABLE IF EXISTS inventory_items CASCADE;

DROP FUNCTION IF EXISTS post_sales_delivery CASCADE;
DROP FUNCTION IF EXISTS post_goods_receipt CASCADE;

-- Restore from backup
psql -U airp_admin airp_master < backup_YYYYMMDD.sql
```

---

## 📚 Additional Resources

- [SAP CO-PA Documentation](https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/f0c8ab08b3494dd19c291b2c31a2c6e1/4b1fce4d6b1f4a8f8c8a9e4c3c4c7e1a.html)
- [Inventory Valuation Methods](https://www.investopedia.com/terms/i/inventory-valuation.asp)
- [Double-Entry Bookkeeping](https://www.accountingtools.com/articles/what-is-double-entry-bookkeeping.html)

---

## 📞 Support

For issues or questions:
- Check logs: `docker compose logs inventory-service`
- Review reconciliation reports for data integrity
- Contact: AIRP Development Team

---

**End of Documentation**
