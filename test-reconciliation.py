#!/usr/bin/env python3
"""
AIRP v2.0 - Bank Reconciliation Test
Tests reconciliation of bank statements with GL entries using real AI
"""
import csv
import json
import requests
from datetime import datetime
from typing import List, Dict

RECON_API = "http://localhost:8002/reconcile"
TENANT_ID = "00000000-0000-0000-0000-000000000001"
BANK_ACCOUNT_ID = "00000000-0000-0000-0000-BA0000000001"

def parse_bank_statement(csv_file: str) -> List[Dict]:
    """Parse Emirates NBD bank statement CSV"""
    bank_transactions = []

    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        txn_id = 1

        for row in reader:
            # Determine if it's debit or credit
            debit = float(row['Debit']) if row['Debit'] else 0
            credit = float(row['Credit']) if row['Credit'] else 0

            amount = -debit if debit > 0 else credit
            txn_type = "debit" if debit > 0 else "credit"

            # Convert date format from DD-Mon-YYYY to YYYY-MM-DD
            date_str = row['Transaction Date']
            try:
                date_obj = datetime.strptime(date_str, '%d-%b-%Y')
                formatted_date = date_obj.strftime('%Y-%m-%d')
            except:
                formatted_date = date_str

            bank_transactions.append({
                "transaction_id": f"BANK-{txn_id:04d}",
                "transaction_date": formatted_date,
                "description": row['Description'],
                "amount": abs(amount),
                "transaction_type": txn_type,
                "reference_number": row['Reference']
            })

            txn_id += 1

    return bank_transactions


def create_mock_gl_transactions() -> List[Dict]:
    """
    Create mock GL transactions that match the bank statement
    In production, these would come from the database
    """
    return [
        {
            "entry_id": "JE-2025-101",
            "entry_date": "2025-01-15",
            "description": "Office rent payment - Dubai Properties",
            "amount": 5000.00,
            "account_code": "5300",
            "account_name": "Rent Expense"
        },
        {
            "entry_id": "JE-2025-102",
            "entry_date": "2025-01-18",
            "description": "Electricity bill payment to DEWA",
            "amount": 1200.00,
            "account_code": "5400",
            "account_name": "Utilities"
        },
        {
            "entry_id": "JE-2025-103",
            "entry_date": "2025-01-21",  # Different date (Jan 21 vs Jan 20 in bank)
            "description": "Monthly salary payment to employees",
            "amount": 25000.00,
            "account_code": "5200",
            "account_name": "Salaries & Wages"
        },
        {
            "entry_id": "JE-2025-104",
            "entry_date": "2025-01-22",
            "description": "G Suite annual subscription",  # Different wording (G Suite vs Google Workspace)
            "amount": 2400.00,
            "account_code": "5900",
            "account_name": "IT & Software"
        },
        {
            "entry_id": "JE-2025-105",
            "entry_date": "2025-01-25",
            "description": "Payment received from Acme Corporation",
            "amount": 15000.00,
            "account_code": "4000",
            "account_name": "Revenue - Sales"
        },
        {
            "entry_id": "JE-2025-106",
            "entry_date": "2025-01-28",
            "description": "Meta advertising campaign spend",  # Different (Meta vs FB ADS)
            "amount": 5000.00,
            "account_code": "5700",
            "account_name": "Marketing & Advertising"
        },
        # Intentionally missing: Office Depot ($850)
        {
            "entry_id": "JE-2025-107",
            "entry_date": "2025-01-31",
            "description": "Bank charges for January",
            "amount": 250.00,
            "account_code": "6200",
            "account_name": "Bank Charges"
        }
    ]


def run_reconciliation(bank_txns: List[Dict], gl_txns: List[Dict]):
    """Run reconciliation via API"""
    payload = {
        "tenant_id": TENANT_ID,
        "account_id": BANK_ACCOUNT_ID,
        "bank_transactions": bank_txns,
        "gl_transactions": gl_txns
    }

    print("Calling AI Reconciliation API...")
    print(f"Bank Transactions: {len(bank_txns)}")
    print(f"GL Transactions: {len(gl_txns)}")
    print()

    try:
        response = requests.post(RECON_API, json=payload, timeout=120)

        if response.status_code == 200:
            return response.json()
        else:
            print(f"ERROR: {response.status_code}")
            print(response.text)
            return None
    except Exception as e:
        print(f"ERROR calling API: {e}")
        return None


def display_results(result: Dict):
    """Display reconciliation results"""
    if not result:
        return

    print("=" * 80)
    print("RECONCILIATION RESULTS")
    print("=" * 80)
    print(f"Account ID: {result['account_id']}")
    print(f"Timestamp: {result['timestamp']}")
    print(f"Processing Time: {result['processing_time_ms']:.0f}ms")
    print(f"Reconciliation Rate: {result['reconciliation_rate']:.1f}%")
    print()

    # Matches
    print(f"MATCHED TRANSACTIONS ({len(result['matches'])})")
    print("-" * 80)

    for match in result['matches']:
        print(f"\nBank: {match['bank_transaction_id']}")
        print(f"  -> GL: {match['gl_transaction_id']}")
        print(f"  Match Type: {match['match_type'].upper()}")
        print(f"  Confidence: {match['confidence_score']:.1%}")
        print(f"  Reasoning: {match['match_reasoning']}")

    print()
    print("=" * 80)

    # Unmatched Bank
    if result['unmatched_bank']:
        print(f"\nUNMATCHED BANK TRANSACTIONS ({len(result['unmatched_bank'])})")
        print("-" * 80)
        for txn_id in result['unmatched_bank']:
            # Find transaction details
            bank_txn = next((t for t in bank_transactions if t['transaction_id'] == txn_id), None)
            if bank_txn:
                print(f"  {txn_id}: {bank_txn['description']} (${bank_txn['amount']:.2f})")

    # Unmatched GL
    if result['unmatched_gl']:
        print(f"\nUNMATCHED GL ENTRIES ({len(result['unmatched_gl'])})")
        print("-" * 80)
        for entry_id in result['unmatched_gl']:
            # Find entry details
            gl_entry = next((t for t in gl_transactions if t['entry_id'] == entry_id), None)
            if gl_entry:
                print(f"  {entry_id}: {gl_entry['description']} (${gl_entry['amount']:.2f})")

    print()
    print("=" * 80)

    # Summary
    total_bank = len(bank_transactions)
    matched = len(result['matches'])
    unmatched_bank_count = len(result['unmatched_bank'])

    print("\nSUMMARY:")
    print(f"  Total Bank Transactions: {total_bank}")
    print(f"  Matched: {matched} ({matched/total_bank*100:.1f}%)")
    print(f"  Unmatched: {unmatched_bank_count} ({unmatched_bank_count/total_bank*100:.1f}%)")
    print()

    # Match type breakdown
    exact_matches = sum(1 for m in result['matches'] if m['match_type'] == 'exact')
    fuzzy_matches = sum(1 for m in result['matches'] if m['match_type'] == 'fuzzy')
    ai_matches = sum(1 for m in result['matches'] if m['match_type'] == 'ai')

    print("MATCH TYPE BREAKDOWN:")
    print(f"  Exact Matches: {exact_matches}")
    print(f"  Fuzzy Matches: {fuzzy_matches}")
    print(f"  AI Matches: {ai_matches}")
    print()

    # Status
    if result['reconciliation_rate'] >= 85:
        print("[EXCELLENT] Reconciliation rate is 85%+")
    elif result['reconciliation_rate'] >= 70:
        print("[GOOD] Reconciliation rate is 70%+")
    elif result['reconciliation_rate'] >= 50:
        print("[FAIR] Reconciliation rate needs improvement")
    else:
        print("[POOR] Significant reconciliation issues")


if __name__ == "__main__":
    print("=" * 80)
    print("AIRP v2.0 - Bank Reconciliation Test")
    print("=" * 80)
    print()

    # Step 1: Parse bank statement
    print("Step 1: Parsing bank statement CSV...")
    csv_file = "test-data/bank-statement-emirates-nbd.csv"
    bank_transactions = parse_bank_statement(csv_file)
    print(f"  Loaded {len(bank_transactions)} bank transactions")
    print()

    # Step 2: Get GL transactions (mock for now)
    print("Step 2: Loading GL transactions...")
    gl_transactions = create_mock_gl_transactions()
    print(f"  Loaded {len(gl_transactions)} GL transactions")
    print()

    # Step 3: Run reconciliation
    print("Step 3: Running AI-powered reconciliation...")
    result = run_reconciliation(bank_transactions, gl_transactions)

    if result:
        # Step 4: Display results
        display_results(result)

        # Save results
        output_file = "reconciliation-test-results.json"
        with open(output_file, 'w') as f:
            json.dump(result, f, indent=2)
        print(f"\nDetailed results saved to: {output_file}")
    else:
        print("\nReconciliation failed!")
