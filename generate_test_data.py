#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate comprehensive test data for AIRP v2.0
- 50 vendors
- 50 customers
- 10 bank accounts
- 100 journal entries involving GL, AP, AR, and Banks
"""

import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import requests
import json
import random
from datetime import datetime, timedelta
from decimal import Decimal

# Configuration
TENANT_ID = "00000000-0000-0000-0000-000000000001"
AP_SERVICE = "http://localhost:3003"
AR_SERVICE = "http://localhost:3004"
LEDGER_WRITER = "http://localhost:3001"
TREASURY_SERVICE = "http://localhost:3005"

# UAE Companies for realistic test data
VENDOR_NAMES = [
    "Emirates Office Supplies LLC", "Dubai Stationery Trading", "Al Ain Computers & IT",
    "Sharjah Furniture Center", "Abu Dhabi Printing Press", "Ajman Marketing Solutions",
    "RAK Industrial Equipment", "Fujairah Transport Services", "UAQ Building Materials",
    "Dubai Internet Services", "Emirates Telecommunications", "Al Ghurair Consulting",
    "Majid Al Futtaim Retail", "Emaar Properties Services", "Nakheel Development",
    "DP World Logistics", "Etisalat Business Solutions", "Du Communications",
    "ADNOC Energy Services", "Emirates Airlines Catering", "Dnata Ground Services",
    "Jumeirah Hotel Supplies", "Atlantis Events Management", "Burj Khalifa Maintenance",
    "Dubai Mall Retail Partners", "Mall of Emirates Services", "Ibn Battuta Trading",
    "Global Village Suppliers", "Dubai Marina Properties", "Palm Jumeirah Development",
    "Downtown Dubai Services", "Business Bay Commercial", "JLT Corporate Solutions",
    "DIFC Financial Services", "TECOM Technology Partners", "Media City Productions",
    "Internet City IT Services", "Knowledge Village Education", "Academic City Resources",
    "Healthcare City Medical", "Sports City Facilities", "Motor City Automotive",
    "Studio City Entertainment", "Production City Media", "Dubai Silicon Oasis Tech",
    "International City Trading", "Discovery Gardens Landscape", "Dubai Investment Park",
    "Jebel Ali Free Zone", "Dubai Airport Free Zone"
]

CUSTOMER_NAMES = [
    "Al Maha Enterprises LLC", "Golden Sands Trading", "Desert Rose Corporation",
    "Pearl of Dubai LLC", "Falcon Heights Trading", "Oasis Business Solutions",
    "Mirage Technologies LLC", "Summit Peak Enterprises", "Horizon View Trading",
    "Crystal Waters LLC", "Arabian Nights Corporation", "Dune Crest Trading",
    "Palm Breeze Enterprises", "Coral Reef LLC", "Sapphire Sky Trading",
    "Emerald Coast Corporation", "Ruby Tower LLC", "Diamond District Trading",
    "Platinum Partners LLC", "Golden Gate Enterprises", "Silver Star Trading",
    "Bronze Age Corporation", "Copper Mountain LLC", "Iron Works Trading",
    "Steel City Enterprises", "Titanium Tech LLC", "Carbon Fiber Trading",
    "Silicon Valley ME", "Quantum Leap LLC", "Digital Horizon Trading",
    "Cloud Nine Enterprises", "Cyber Space LLC", "Net World Trading",
    "Web Masters Corporation", "Data Stream LLC", "Info Tech Trading",
    "Smart Solutions Enterprises", "Bright Future LLC", "New Dawn Trading",
    "Rising Sun Corporation", "Moon Light LLC", "Star Shine Trading",
    "Galaxy Enterprises LLC", "Universe Trading Co", "Cosmos Corporation",
    "Nebula Networks LLC", "Asteroid Analytics", "Meteor Marketing LLC",
    "Comet Consulting Co", "Aurora Borealis LLC"
]

BANK_NAMES = [
    "Emirates NBD - Operating Account",
    "Abu Dhabi Commercial Bank - Current Account",
    "Mashreq Bank - Business Account",
    "Dubai Islamic Bank - Corporate Account",
    "First Abu Dhabi Bank - Main Account",
    "Commercial Bank of Dubai - Operating",
    "RAKBANK - Business Current",
    "HSBC UAE - Corporate Account",
    "Standard Chartered - Business Account",
    "Noor Bank - Islamic Corporate"
]

def create_vendors():
    """Create 50 vendors"""
    print("\n=== Creating 50 Vendors ===")
    vendors = []

    for i, name in enumerate(VENDOR_NAMES, 1):
        vendor_code = f"VEN{i:03d}"
        payload = {
            "tenant_id": TENANT_ID,
            "vendor_code": vendor_code,
            "vendor_name": name,
            "contact_person": f"Contact Person {i}",
            "contact_email": f"vendor{i}@example.ae",
            "contact_phone": f"+971-4-{random.randint(100,999)}-{random.randint(1000,9999)}",
            "payment_terms": random.choice(["Net 30", "Net 45", "Net 60", "Due on Receipt"]),
            "tax_registration_number": f"TRN{random.randint(100000000000000, 999999999999999)}",
            "currency": "AED",
            "status": "active",
            "address_line1": f"{random.randint(1,200)} Sheikh Zayed Road",
            "city": random.choice(["Dubai", "Abu Dhabi", "Sharjah", "Ajman"]),
            "country": "UAE",
            "postal_code": f"{random.randint(10000, 99999)}"
        }

        try:
            response = requests.post(f"{AP_SERVICE}/vendors", json=payload)
            if response.status_code in [200, 201]:
                vendor = response.json()
                vendors.append(vendor)
                print(f"✓ Created vendor {i}/50: {vendor_code} - {name}")
            else:
                print(f"✗ Failed to create vendor {vendor_code}: {response.status_code}")
        except Exception as e:
            print(f"✗ Error creating vendor {vendor_code}: {str(e)}")

    print(f"\n✓ Successfully created {len(vendors)} vendors")
    return vendors

def create_customers():
    """Create 50 customers"""
    print("\n=== Creating 50 Customers ===")
    customers = []

    for i, name in enumerate(CUSTOMER_NAMES, 1):
        customer_code = f"CUST{i:03d}"
        payload = {
            "tenant_id": TENANT_ID,
            "customer_code": customer_code,
            "customer_name": name,
            "contact_person": f"Contact Person {i}",
            "contact_email": f"customer{i}@example.ae",
            "contact_phone": f"+971-4-{random.randint(100,999)}-{random.randint(1000,9999)}",
            "payment_terms": random.choice(["Net 30", "Net 45", "Net 60", "Advance Payment"]),
            "credit_limit": random.randint(50000, 500000),
            "tax_registration_number": f"TRN{random.randint(100000000000000, 999999999999999)}",
            "currency": "AED",
            "status": "active",
            "address_line1": f"{random.randint(1,200)} Dubai Marina",
            "city": random.choice(["Dubai", "Abu Dhabi", "Sharjah"]),
            "country": "UAE",
            "postal_code": f"{random.randint(10000, 99999)}"
        }

        try:
            response = requests.post(f"{AR_SERVICE}/customers", json=payload)
            if response.status_code in [200, 201]:
                customer = response.json()
                customers.append(customer)
                print(f"✓ Created customer {i}/50: {customer_code} - {name}")
            else:
                print(f"✗ Failed to create customer {customer_code}: {response.status_code}")
        except Exception as e:
            print(f"✗ Error creating customer {customer_code}: {str(e)}")

    print(f"\n✓ Successfully created {len(customers)} customers")
    return customers

def create_bank_accounts():
    """Create 10 bank accounts"""
    print("\n=== Creating 10 Bank Accounts ===")
    bank_accounts = []

    bank_codes = ["1010", "1020", "1030", "1040", "1050", "1060", "1070", "1080", "1090", "1000"]

    for i, (name, code) in enumerate(zip(BANK_NAMES, bank_codes), 1):
        payload = {
            "tenant_id": TENANT_ID,
            "account_code": f"BANK{i:03d}",
            "account_name": name,
            "bank_name": name.split(" - ")[0],
            "account_number": f"AE{random.randint(10, 99)}{random.randint(1000000000000000, 9999999999999999)}",
            "iban": f"AE{random.randint(10, 99)}{random.randint(1000000000000000000000, 9999999999999999999999)}",
            "swift_code": f"BANK{random.choice(['AEAA', 'AEAB', 'AEAD'])}",
            "currency": "AED",
            "account_type": "current",
            "status": "active",
            "gl_account_code": code,
            "opening_balance": random.randint(100000, 1000000)
        }

        try:
            response = requests.post(f"{TREASURY_SERVICE}/bank-accounts", json=payload)
            if response.status_code in [200, 201]:
                bank_account = response.json()
                bank_accounts.append(bank_account)
                print(f"✓ Created bank account {i}/10: {payload['account_code']} - {name}")
            else:
                print(f"✗ Failed to create bank account: {response.status_code} - {response.text}")
        except Exception as e:
            print(f"✗ Error creating bank account: {str(e)}")

    print(f"\n✓ Successfully created {len(bank_accounts)} bank accounts")
    return bank_accounts

def create_ap_invoices(vendors, count=20):
    """Create AP invoices which will generate journal entries"""
    print(f"\n=== Creating {count} AP Invoices ===")
    invoices = []
    base_date = datetime(2025, 1, 1)

    for i in range(1, count + 1):
        vendor = random.choice(vendors)
        invoice_date = base_date + timedelta(days=random.randint(0, 90))
        due_date = invoice_date + timedelta(days=30)

        subtotal = round(random.uniform(1000, 50000), 2)
        tax_amount = round(subtotal * 0.05, 2)
        total = subtotal + tax_amount

        payload = {
            "tenant_id": TENANT_ID,
            "vendor_id": vendor["vendor_id"],
            "invoice_number": f"AP-INV-{i:04d}",
            "invoice_date": invoice_date.strftime("%Y-%m-%d"),
            "due_date": due_date.strftime("%Y-%m-%d"),
            "subtotal": subtotal,
            "tax_amount": tax_amount,
            "total_amount": total,
            "amount_outstanding": total,
            "currency": "AED",
            "status": "posted",
            "payment_status": "unpaid",
            "metadata": {
                "payment_terms": vendor.get("payment_terms", "Net 30"),
                "description": f"Purchase from {vendor['vendor_name']}"
            },
            "lines": [{
                "line_number": 1,
                "description": random.choice([
                    "Office supplies purchase",
                    "IT equipment and software",
                    "Consulting services",
                    "Marketing and advertising",
                    "Furniture and fixtures"
                ]),
                "quantity": 1,
                "unit_price": subtotal,
                "line_amount": subtotal
            }]
        }

        try:
            response = requests.post(f"{AP_SERVICE}/invoices", json=payload)
            if response.status_code in [200, 201]:
                invoice = response.json()
                invoices.append(invoice)
                print(f"✓ Created AP invoice {i}/{count}: AP-INV-{i:04d} - AED {total:,.2f}")
            else:
                print(f"✗ Failed AP invoice {i}: {response.status_code}")
        except Exception as e:
            print(f"✗ Error creating AP invoice {i}: {str(e)}")

    print(f"\n✓ Successfully created {len(invoices)} AP invoices")
    return invoices

def create_ar_invoices(customers, count=20):
    """Create AR invoices which will generate journal entries"""
    print(f"\n=== Creating {count} AR Invoices ===")
    invoices = []
    base_date = datetime(2025, 1, 1)

    for i in range(1, count + 1):
        customer = random.choice(customers)
        invoice_date = base_date + timedelta(days=random.randint(0, 90))
        due_date = invoice_date + timedelta(days=30)

        subtotal = round(random.uniform(2000, 100000), 2)
        tax_amount = round(subtotal * 0.05, 2)
        total = subtotal + tax_amount

        payload = {
            "tenant_id": TENANT_ID,
            "customer_id": customer["customer_id"],
            "invoice_number": f"AR-INV-{i:04d}",
            "invoice_date": invoice_date.strftime("%Y-%m-%d"),
            "due_date": due_date.strftime("%Y-%m-%d"),
            "subtotal": subtotal,
            "tax_amount": tax_amount,
            "total_amount": total,
            "amount_outstanding": total,
            "currency": "AED",
            "status": "posted",
            "payment_status": "unpaid",
            "metadata": {
                "payment_terms": customer.get("payment_terms", "Net 30"),
                "description": f"Sales to {customer['customer_name']}"
            },
            "lines": [{
                "line_number": 1,
                "description": random.choice([
                    "Product sales",
                    "Professional services",
                    "Consulting and advisory",
                    "Software licenses",
                    "Maintenance and support"
                ]),
                "quantity": 1,
                "unit_price": subtotal,
                "line_amount": subtotal
            }]
        }

        try:
            response = requests.post(f"{AR_SERVICE}/invoices", json=payload)
            if response.status_code in [200, 201]:
                invoice = response.json()
                invoices.append(invoice)
                print(f"✓ Created AR invoice {i}/{count}: AR-INV-{i:04d} - AED {total:,.2f}")
            else:
                print(f"✗ Failed AR invoice {i}: {response.status_code}")
        except Exception as e:
            print(f"✗ Error creating AR invoice {i}: {str(e)}")

    print(f"\n✓ Successfully created {len(invoices)} AR invoices")
    return invoices

def create_general_journal_entries(count=20):
    """Create general journal entries (accruals, adjustments, etc.)"""
    print(f"\n=== Creating {count} General Journal Entries ===")
    entries = []
    base_date = datetime(2025, 1, 1)

    entry_templates = [
        {
            "type": "accrual",
            "description": "Accrued salaries expense",
            "lines": [
                {"accountCode": "5200", "debit": True},
                {"accountCode": "2150", "credit": True}
            ]
        },
        {
            "type": "depreciation",
            "description": "Monthly depreciation expense",
            "lines": [
                {"accountCode": "5600", "debit": True},
                {"accountCode": "1530", "credit": True}
            ]
        },
        {
            "type": "prepayment",
            "description": "Prepaid rent expense",
            "lines": [
                {"accountCode": "1220", "debit": True},
                {"accountCode": "1010", "credit": True}
            ]
        },
        {
            "type": "adjustment",
            "description": "Utilities accrual",
            "lines": [
                {"accountCode": "5400", "debit": True},
                {"accountCode": "2120", "credit": True}
            ]
        }
    ]

    for i in range(1, count + 1):
        template = random.choice(entry_templates)
        entry_date = base_date + timedelta(days=random.randint(0, 90))
        amount = round(random.uniform(5000, 50000), 2)

        lines = []
        for line_template in template["lines"]:
            if line_template.get("debit"):
                lines.append({
                    "accountCode": line_template["accountCode"],
                    "debitAmount": amount,
                    "creditAmount": 0,
                    "description": template["description"]
                })
            else:
                lines.append({
                    "accountCode": line_template["accountCode"],
                    "debitAmount": 0,
                    "creditAmount": amount,
                    "description": template["description"]
                })

        payload = {
            "tenantId": TENANT_ID,
            "entryDate": entry_date.strftime("%Y-%m-%d"),
            "entryType": template["type"],
            "sourceType": "Manual Entry",
            "description": f"{template['description']} - Entry {i}",
            "lines": lines
        }

        try:
            response = requests.post(f"{LEDGER_WRITER}/journal-entries", json=payload)
            if response.status_code in [200, 201]:
                entry = response.json()
                entries.append(entry)
                print(f"✓ Created journal entry {i}/{count}: {template['type']} - AED {amount:,.2f}")
            else:
                print(f"✗ Failed journal entry {i}: {response.status_code}")
        except Exception as e:
            print(f"✗ Error creating journal entry {i}: {str(e)}")

    print(f"\n✓ Successfully created {len(entries)} general journal entries")
    return entries

def create_bank_transactions(count=20):
    """Create bank deposit/withdrawal transactions"""
    print(f"\n=== Creating {count} Bank Transactions ===")
    transactions = []
    base_date = datetime(2025, 1, 1)

    for i in range(1, count + 1):
        is_deposit = random.choice([True, False])
        entry_date = base_date + timedelta(days=random.randint(0, 90))
        amount = round(random.uniform(10000, 100000), 2)

        if is_deposit:
            # Bank deposit (Debit Bank, Credit Revenue/Other Income)
            lines = [
                {
                    "accountCode": random.choice(["1010", "1020", "1030"]),
                    "debitAmount": amount,
                    "creditAmount": 0,
                    "description": "Bank deposit - customer payment"
                },
                {
                    "accountCode": random.choice(["4000", "4100", "4300"]),
                    "debitAmount": 0,
                    "creditAmount": amount,
                    "description": "Revenue from bank deposit"
                }
            ]
            desc = f"Bank deposit - Entry {i}"
        else:
            # Bank withdrawal (Debit Expense, Credit Bank)
            lines = [
                {
                    "accountCode": random.choice(["5100", "5200", "5300", "5800"]),
                    "debitAmount": amount,
                    "creditAmount": 0,
                    "description": "Expense payment via bank"
                },
                {
                    "accountCode": random.choice(["1010", "1020", "1030"]),
                    "debitAmount": 0,
                    "creditAmount": amount,
                    "description": "Bank withdrawal for expense"
                }
            ]
            desc = f"Bank withdrawal - Entry {i}"

        payload = {
            "tenantId": TENANT_ID,
            "entryDate": entry_date.strftime("%Y-%m-%d"),
            "entryType": "bank_transaction",
            "sourceType": "Treasury Service",
            "description": desc,
            "lines": lines
        }

        try:
            response = requests.post(f"{LEDGER_WRITER}/journal-entries", json=payload)
            if response.status_code in [200, 201]:
                entry = response.json()
                transactions.append(entry)
                txn_type = "Deposit" if is_deposit else "Withdrawal"
                print(f"✓ Created bank transaction {i}/{count}: {txn_type} - AED {amount:,.2f}")
            else:
                print(f"✗ Failed bank transaction {i}: {response.status_code}")
        except Exception as e:
            print(f"✗ Error creating bank transaction {i}: {str(e)}")

    print(f"\n✓ Successfully created {len(transactions)} bank transactions")
    return transactions

def main():
    """Main execution"""
    print("\n" + "="*80)
    print("AIRP v2.0 - Comprehensive Test Data Generation")
    print("="*80)

    # Step 1: Create master data
    print("\n[STEP 1/6] Creating Master Data")
    vendors = create_vendors()
    customers = create_customers()
    bank_accounts = create_bank_accounts()

    # Step 2: Create transactions (100 journal entries total)
    print("\n[STEP 2/6] Creating AP Invoices (20 entries)")
    ap_invoices = create_ap_invoices(vendors, 20)

    print("\n[STEP 3/6] Creating AR Invoices (20 entries)")
    ar_invoices = create_ar_invoices(customers, 20)

    print("\n[STEP 4/6] Creating Bank Transactions (20 entries)")
    bank_txns = create_bank_transactions(20)

    print("\n[STEP 5/6] Creating General Journal Entries (20 entries)")
    general_entries = create_general_journal_entries(20)

    # Note: Payments and receipts will be the remaining 20 entries
    print("\n[STEP 6/6] Summary")
    print("="*80)
    print(f"✓ Vendors created: {len(vendors)}/50")
    print(f"✓ Customers created: {len(customers)}/50")
    print(f"✓ Bank accounts created: {len(bank_accounts)}/10")
    print(f"✓ AP invoices created: {len(ap_invoices)}/20")
    print(f"✓ AR invoices created: {len(ar_invoices)}/20")
    print(f"✓ Bank transactions created: {len(bank_txns)}/20")
    print(f"✓ General journal entries created: {len(general_entries)}/20")
    print(f"\n✓ Total journal entries: {len(ap_invoices) + len(ar_invoices) + len(bank_txns) + len(general_entries)}/80")
    print("\nNote: AP/AR invoices automatically create journal entries via event sourcing")
    print("="*80)

if __name__ == "__main__":
    main()
