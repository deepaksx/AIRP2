#!/usr/bin/env python3
"""
Comprehensive Test Data Generator for AIRP v2.12.0
Generates 100+ transactions across all modules using Universal Journal
"""

import psycopg2
import uuid
from datetime import datetime, timedelta
from decimal import Decimal
import random
import json

# Database connection
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'airp_master',
    'user': 'airp_admin',
    'password': 'airp_secure_2024'
}

TENANT_ID = '00000000-0000-0000-0000-000000000001'

# Get vendors and customers
def get_vendors(cursor):
    cursor.execute("SELECT vendor_id, vendor_code, vendor_name, payment_terms FROM vendors WHERE tenant_id = %s", (TENANT_ID,))
    return cursor.fetchall()

def get_customers(cursor):
    cursor.execute("SELECT customer_id, customer_code, customer_name, payment_terms FROM customers WHERE tenant_id = %s", (TENANT_ID,))
    return cursor.fetchall()

def get_account_id(cursor, account_code):
    cursor.execute("SELECT account_id FROM chart_of_accounts WHERE account_code = %s AND tenant_id = %s", (account_code, TENANT_ID))
    result = cursor.fetchone()
    return result[0] if result else None

def create_journal_entry(cursor, entry_number, entry_date, description, entry_type, lines):
    """Create journal entry with Universal Journal metadata"""
    entry_id = str(uuid.uuid4())

    total_debit = sum(line['debit_amount'] for line in lines)
    total_credit = sum(line['credit_amount'] for line in lines)

    if abs(total_debit - total_credit) > 0.01:
        raise ValueError(f"Entry {entry_number} not balanced: Dr={total_debit}, Cr={total_credit}")

    # Insert journal entry header
    cursor.execute("""
        INSERT INTO journal_entries (
            entry_id, tenant_id, entry_number, entry_date, posting_date,
            entry_type, source_type, description, total_debit, total_credit, status
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'posted')
    """, (
        entry_id, TENANT_ID, entry_number, entry_date, entry_date,
        entry_type, 'system_generated', description, total_debit, total_credit
    ))

    # Insert journal entry lines with metadata
    for line in lines:
        line_id = str(uuid.uuid4())
        cursor.execute("""
            INSERT INTO journal_entry_lines (
                line_id, entry_id, tenant_id, account_id,
                debit_amount, credit_amount, description,
                dimension_1, dimension_2, dimension_3, dimension_4, metadata
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            line_id, entry_id, TENANT_ID, line['account_id'],
            line['debit_amount'], line['credit_amount'], line['description'],
            line.get('dimension_1'), line.get('dimension_2'),
            line.get('dimension_3'), line.get('dimension_4'),
            json.dumps(line.get('metadata', {}))
        ))

    return entry_id

def generate_ap_invoices(cursor, vendors, num_invoices=30):
    """Generate AP invoices using Universal Journal"""
    print(f"\n[1/6] Generating {num_invoices} AP Invoices...")

    ap_control_account = get_account_id(cursor, '2100')  # Accounts Payable
    expense_accounts = [
        get_account_id(cursor, '5100'),  # Operating Expenses
        get_account_id(cursor, '5200'),  # Rent Expense
        get_account_id(cursor, '5300'),  # Utilities Expense
        get_account_id(cursor, '5400'),  # Insurance Expense
    ]

    start_date = datetime.now() - timedelta(days=90)

    for i in range(num_invoices):
        vendor = random.choice(vendors)
        vendor_id, vendor_code, vendor_name, payment_terms = vendor

        invoice_date = start_date + timedelta(days=random.randint(0, 90))
        due_days = int(payment_terms.split()[1]) if 'Net' in payment_terms else 30
        due_date = invoice_date + timedelta(days=due_days)

        subtotal = Decimal(random.randint(500, 5000))
        tax_amount = subtotal * Decimal('0.05')  # 5% VAT
        total_amount = subtotal + tax_amount

        invoice_number = f"INV-AP-{invoice_date.year}-{i+1:04d}"
        entry_number = f"JE-AP-{invoice_date.year}-{i+1:04d}"

        # Determine payment status based on due date
        days_outstanding = (datetime.now() - due_date).days
        if days_outstanding < -30:
            payment_status = 'unpaid'
            amount_outstanding = total_amount
        elif days_outstanding < 0:
            payment_status = 'unpaid'
            amount_outstanding = total_amount
        elif random.random() < 0.3:  # 30% paid
            payment_status = 'paid'
            amount_outstanding = Decimal('0')
        elif random.random() < 0.5:  # 20% partial
            payment_status = 'partial'
            amount_outstanding = total_amount * Decimal(random.uniform(0.3, 0.7))
        else:
            payment_status = 'unpaid'
            amount_outstanding = total_amount

        # Create metadata for Universal Journal
        metadata = {
            'source_type': 'ap_invoice',
            'invoice_number': invoice_number,
            'invoice_date': invoice_date.strftime('%Y-%m-%d'),
            'due_date': due_date.strftime('%Y-%m-%d'),
            'payment_terms': payment_terms,
            'payment_status': payment_status,
            'total_amount': float(total_amount),
            'amount_paid': float(total_amount - amount_outstanding),
            'amount_outstanding': float(amount_outstanding),
            'subtotal': float(subtotal),
            'tax_amount': float(tax_amount),
            'currency': 'AED',
            'vendor_code': vendor_code,
            'vendor_name': vendor_name
        }

        # Journal Entry:  Dr Expense, Cr AP
        lines = [
            {
                'account_id': random.choice(expense_accounts),
                'debit_amount': float(total_amount),
                'credit_amount': 0,
                'description': f'Invoice {invoice_number} from {vendor_name}',
                'dimension_1': None,
                'dimension_2': None,
                'metadata': {}
            },
            {
                'account_id': ap_control_account,
                'debit_amount': 0,
                'credit_amount': float(total_amount),
                'description': f'Invoice {invoice_number} from {vendor_name}',
                'dimension_1': str(vendor_id),  # Vendor tracking
                'dimension_2': None,
                'metadata': metadata  # Universal Journal metadata on AP line
            }
        ]

        create_journal_entry(cursor, entry_number, invoice_date, f'AP Invoice {invoice_number}', 'AP Invoice', lines)

        if i % 10 == 0:
            print(f"  Created {i+1}/{num_invoices} AP invoices")

    print(f"  ✅ Created {num_invoices} AP invoices")

def generate_ar_invoices(cursor, customers, num_invoices=30):
    """Generate AR invoices using Universal Journal"""
    print(f"\n[2/6] Generating {num_invoices} AR Invoices...")

    ar_control_account = get_account_id(cursor, '1200')  # Accounts Receivable
    revenue_accounts = [
        get_account_id(cursor, '4000'),  # Revenue
        get_account_id(cursor, '4100'),  # Service Revenue
        get_account_id(cursor, '4200'),  # Consulting Revenue
    ]

    start_date = datetime.now() - timedelta(days=90)

    for i in range(num_invoices):
        customer = random.choice(customers)
        customer_id, customer_code, customer_name, payment_terms = customer

        invoice_date = start_date + timedelta(days=random.randint(0, 90))
        due_days = int(payment_terms.split()[1]) if 'Net' in payment_terms else 30
        due_date = invoice_date + timedelta(days=due_days)

        subtotal = Decimal(random.randint(1000, 10000))
        tax_amount = subtotal * Decimal('0.05')  # 5% VAT
        total_amount = subtotal + tax_amount

        invoice_number = f"INV-AR-{invoice_date.year}-{i+1:04d}"
        entry_number = f"JE-AR-{invoice_date.year}-{i+1:04d}"

        # Determine payment status
        days_outstanding = (datetime.now() - due_date).days
        if days_outstanding < -30:
            payment_status = 'unpaid'
            amount_outstanding = total_amount
        elif days_outstanding < 0:
            payment_status = 'unpaid'
            amount_outstanding = total_amount
        elif random.random() < 0.4:  # 40% paid
            payment_status = 'paid'
            amount_outstanding = Decimal('0')
        elif random.random() < 0.3:  # 18% partial
            payment_status = 'partial'
            amount_outstanding = total_amount * Decimal(random.uniform(0.2, 0.6))
        else:
            payment_status = 'unpaid'
            amount_outstanding = total_amount

        # Create metadata for Universal Journal
        metadata = {
            'source_type': 'ar_invoice',
            'invoice_number': invoice_number,
            'invoice_date': invoice_date.strftime('%Y-%m-%d'),
            'due_date': due_date.strftime('%Y-%m-%d'),
            'payment_terms': payment_terms,
            'payment_status': payment_status,
            'total_amount': float(total_amount),
            'amount_paid': float(total_amount - amount_outstanding),
            'amount_outstanding': float(amount_outstanding),
            'subtotal': float(subtotal),
            'tax_amount': float(tax_amount),
            'currency': 'AED',
            'customer_code': customer_code,
            'customer_name': customer_name
        }

        # Journal Entry: Dr AR, Cr Revenue
        lines = [
            {
                'account_id': ar_control_account,
                'debit_amount': float(total_amount),
                'credit_amount': 0,
                'description': f'Invoice {invoice_number} to {customer_name}',
                'dimension_1': None,
                'dimension_2': str(customer_id),  # Customer tracking
                'metadata': metadata  # Universal Journal metadata on AR line
            },
            {
                'account_id': random.choice(revenue_accounts),
                'debit_amount': 0,
                'credit_amount': float(total_amount),
                'description': f'Invoice {invoice_number} to {customer_name}',
                'dimension_1': None,
                'dimension_2': None,
                'metadata': {}
            }
        ]

        create_journal_entry(cursor, entry_number, invoice_date, f'AR Invoice {invoice_number}', 'AR Invoice', lines)

        if i % 10 == 0:
            print(f"  Created {i+1}/{num_invoices} AR invoices")

    print(f"  ✅ Created {num_invoices} AR invoices")

def generate_payments(cursor, num_payments=20):
    """Generate cash payments and receipts"""
    print(f"\n[3/6] Generating {num_payments} Payments...")

    cash_account = get_account_id(cursor, '1010')  # Bank - Emirates NBD
    ap_account = get_account_id(cursor, '2100')  # AP
    ar_account = get_account_id(cursor, '1200')  # AR

    start_date = datetime.now() - timedelta(days=60)

    for i in range(num_payments):
        payment_date = start_date + timedelta(days=random.randint(0, 60))
        amount = Decimal(random.randint(1000, 8000))

        if i % 2 == 0:  # AP Payment
            entry_number = f"JE-PMT-AP-{payment_date.year}-{i+1:04d}"
            description = f"Vendor payment #{i+1}"

            metadata = {
                'source_type': 'payment',
                'payment_type': 'vendor_payment',
                'payment_date': payment_date.strftime('%Y-%m-%d'),
                'payment_amount': float(amount),
                'payment_method': random.choice(['wire_transfer', 'check', 'ach']),
                'reference': f"PMT-{i+1:06d}"
            }

            lines = [
                {'account_id': ap_account, 'debit_amount': float(amount), 'credit_amount': 0, 'description': description, 'dimension_1': None, 'dimension_2': None, 'metadata': metadata},
                {'account_id': cash_account, 'debit_amount': 0, 'credit_amount': float(amount), 'description': description, 'dimension_1': None, 'dimension_2': None, 'metadata': {}}
            ]
        else:  # AR Receipt
            entry_number = f"JE-RCT-AR-{payment_date.year}-{i+1:04d}"
            description = f"Customer receipt #{i+1}"

            metadata = {
                'source_type': 'receipt',
                'payment_type': 'customer_receipt',
                'payment_date': payment_date.strftime('%Y-%m-%d'),
                'payment_amount': float(amount),
                'payment_method': random.choice(['wire_transfer', 'check', 'credit_card']),
                'reference': f"RCT-{i+1:06d}"
            }

            lines = [
                {'account_id': cash_account, 'debit_amount': float(amount), 'credit_amount': 0, 'description': description, 'dimension_1': None, 'dimension_2': None, 'metadata': {}},
                {'account_id': ar_account, 'debit_amount': 0, 'credit_amount': float(amount), 'description': description, 'dimension_1': None, 'dimension_2': None, 'metadata': metadata}
            ]

        create_journal_entry(cursor, entry_number, payment_date, description, 'Payment', lines)

        if i % 5 == 0:
            print(f"  Created {i+1}/{num_payments} payments")

    print(f"  ✅ Created {num_payments} payments")

def generate_payroll(cursor, num_entries=12):
    """Generate monthly payroll entries"""
    print(f"\n[4/6] Generating {num_entries} Payroll Entries...")

    salary_account = get_account_id(cursor, '5000')  # Salaries Expense
    bank_account = get_account_id(cursor, '1010')  # Bank

    start_date = datetime.now() - timedelta(days=365)

    for i in range(num_entries):
        payroll_date = start_date + timedelta(days=30*i)
        amount = Decimal(random.randint(45000, 55000))

        entry_number = f"JE-PAY-{payroll_date.year}-{payroll_date.month:02d}"
        description = f"Payroll for {payroll_date.strftime('%B %Y')}"

        metadata = {
            'source_type': 'payroll',
            'payroll_period': payroll_date.strftime('%Y-%m'),
            'employee_count': random.randint(8, 12),
            'total_gross': float(amount),
            'payment_date': payroll_date.strftime('%Y-%m-%d')
        }

        lines = [
            {'account_id': salary_account, 'debit_amount': float(amount), 'credit_amount': 0, 'description': description, 'dimension_1': None, 'dimension_2': None, 'metadata': metadata},
            {'account_id': bank_account, 'debit_amount': 0, 'credit_amount': float(amount), 'description': description, 'dimension_1': None, 'dimension_2': None, 'metadata': {}}
        ]

        create_journal_entry(cursor, entry_number, payroll_date, description, 'Payroll', lines)

    print(f"  ✅ Created {num_entries} payroll entries")

def generate_adjustments(cursor, num_entries=10):
    """Generate period-end adjustments"""
    print(f"\n[5/6] Generating {num_entries} Adjusting Entries...")

    prepaid_account = get_account_id(cursor, '1300')  # Prepaid Expenses
    insurance_expense = get_account_id(cursor, '5400')  # Insurance Expense
    depreciation_expense = get_account_id(cursor, '5600')  # Depreciation Expense
    accumulated_dep = get_account_id(cursor, '1520')  # Accumulated Depreciation

    start_date = datetime.now() - timedelta(days=90)

    for i in range(num_entries):
        adj_date = start_date + timedelta(days=30*i)
        entry_number = f"JE-ADJ-{adj_date.year}-{i+1:03d}"

        if i % 2 == 0:  # Prepaid amortization
            amount = Decimal(random.randint(500, 2000))
            description = f"Amortize prepaid expenses - {adj_date.strftime('%B %Y')}"

            metadata = {
                'source_type': 'adjustment',
                'adjustment_type': 'prepaid_amortization',
                'period': adj_date.strftime('%Y-%m')
            }

            lines = [
                {'account_id': insurance_expense, 'debit_amount': float(amount), 'credit_amount': 0, 'description': description, 'dimension_1': None, 'dimension_2': None, 'metadata': metadata},
                {'account_id': prepaid_account, 'debit_amount': 0, 'credit_amount': float(amount), 'description': description, 'dimension_1': None, 'dimension_2': None, 'metadata': {}}
            ]
        else:  # Depreciation
            amount = Decimal(random.randint(1000, 3000))
            description = f"Record depreciation - {adj_date.strftime('%B %Y')}"

            metadata = {
                'source_type': 'adjustment',
                'adjustment_type': 'depreciation',
                'period': adj_date.strftime('%Y-%m')
            }

            lines = [
                {'account_id': depreciation_expense, 'debit_amount': float(amount), 'credit_amount': 0, 'description': description, 'dimension_1': None, 'dimension_2': None, 'metadata': metadata},
                {'account_id': accumulated_dep, 'debit_amount': 0, 'credit_amount': float(amount), 'description': description, 'dimension_1': None, 'dimension_2': None, 'metadata': {}}
            ]

        create_journal_entry(cursor, entry_number, adj_date, description, 'Adjusting', lines)

    print(f"  ✅ Created {num_entries} adjusting entries")

def update_gl_balances(cursor):
    """Update GL balances from journal entries"""
    print(f"\n[6/6] Updating GL Balances...")

    cursor.execute("""
        INSERT INTO gl_balances (tenant_id, account_id, fiscal_year, fiscal_period, currency, debit_amount, credit_amount, balance)
        SELECT
            jel.tenant_id,
            jel.account_id,
            EXTRACT(YEAR FROM je.entry_date)::INTEGER,
            EXTRACT(MONTH FROM je.entry_date)::INTEGER,
            'AED',
            SUM(jel.debit_amount),
            SUM(jel.credit_amount),
            SUM(jel.debit_amount) - SUM(jel.credit_amount)
        FROM journal_entry_lines jel
        JOIN journal_entries je ON jel.entry_id = je.entry_id
        WHERE je.status = 'posted'
        GROUP BY jel.tenant_id, jel.account_id, EXTRACT(YEAR FROM je.entry_date), EXTRACT(MONTH FROM je.entry_date)
        ON CONFLICT (tenant_id, account_id, fiscal_year, fiscal_period, currency)
        DO UPDATE SET
            debit_amount = EXCLUDED.debit_amount,
            credit_amount = EXCLUDED.credit_amount,
            balance = EXCLUDED.balance
    """)

    # Refresh materialized views
    cursor.execute("REFRESH MATERIALIZED VIEW trial_balance")
    cursor.execute("REFRESH MATERIALIZED VIEW mv_ap_aging")
    cursor.execute("REFRESH MATERIALIZED VIEW mv_ar_aging")

    print(f"  ✅ GL balances updated and materialized views refreshed")

def main():
    print("=" * 60)
    print("AIRP v2.12.0 - Comprehensive Test Data Generator")
    print("Universal Journal Architecture")
    print("=" * 60)

    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = False
    cursor = conn.cursor()

    try:
        # Get master data
        vendors = get_vendors(cursor)
        customers = get_customers(cursor)

        print(f"\nMaster Data:")
        print(f"  Vendors: {len(vendors)}")
        print(f"  Customers: {len(customers)}")

        # Generate transactions
        generate_ap_invoices(cursor, vendors, num_invoices=30)
        generate_ar_invoices(cursor, customers, num_invoices=30)
        generate_payments(cursor, num_payments=20)
        generate_payroll(cursor, num_entries=12)
        generate_adjustments(cursor, num_entries=10)

        # Update GL balances
        update_gl_balances(cursor)

        conn.commit()

        # Summary
        cursor.execute("SELECT COUNT(*) FROM journal_entries")
        je_count = cursor.fetchone()[0]

        cursor.execute("SELECT COUNT(*) FROM journal_entry_lines")
        jel_count = cursor.fetchone()[0]

        cursor.execute("SELECT COUNT(*) FROM vw_ap_invoices")
        ap_count = cursor.fetchone()[0]

        cursor.execute("SELECT COUNT(*) FROM vw_ar_invoices")
        ar_count = cursor.fetchone()[0]

        print("\n" + "=" * 60)
        print("GENERATION COMPLETE")
        print("=" * 60)
        print(f"Journal Entries:     {je_count}")
        print(f"Journal Lines:       {jel_count}")
        print(f"AP Invoices:         {ap_count}")
        print(f"AR Invoices:         {ar_count}")
        print("=" * 60)
        print("\n✅ All test data created successfully!")
        print("Ready for testing all reports and Cash Flow functionality\n")

    except Exception as e:
        conn.rollback()
        print(f"\n❌ Error: {e}")
        raise
    finally:
        cursor.close()
        conn.close()

if __name__ == '__main__':
    main()
