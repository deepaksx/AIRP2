#!/usr/bin/env python3
"""
AIRP v2.0 - AI Classification Comprehensive Test
Tests AI classification with 20 varied transaction descriptions
"""
import json
import time
import requests
from datetime import datetime
from typing import List, Dict

API_URL = "http://localhost:8001/classify"
TENANT_ID = "00000000-0000-0000-0000-000000000001"

# Test cases with expected account codes
TEST_TRANSACTIONS = [
    # Rent & Utilities
    {
        "description": "Office rent payment for January 2025",
        "vendor": "Dubai Properties LLC",
        "amount": 5000.00,
        "expected_code": "5300",
        "expected_name": "Rent Expense"
    },
    {
        "description": "DEWA electricity bill for December",
        "vendor": "DEWA",
        "amount": 1200.00,
        "expected_code": "5400",
        "expected_name": "Utilities"
    },
    {
        "description": "Water charges for office premises",
        "vendor": "DEWA",
        "amount": 450.00,
        "expected_code": "5400",
        "expected_name": "Utilities"
    },

    # Salaries & Payroll
    {
        "description": "Monthly salary payment to employees",
        "vendor": "HR Department",
        "amount": 25000.00,
        "expected_code": "5200",
        "expected_name": "Salaries & Wages"
    },
    {
        "description": "Payroll processing for December 2024",
        "vendor": "Finance Team",
        "amount": 18000.00,
        "expected_code": "5200",
        "expected_name": "Salaries & Wages"
    },

    # IT & Software
    {
        "description": "Google Workspace subscription annual renewal",
        "vendor": "Google LLC",
        "amount": 2400.00,
        "expected_code": "5900",
        "expected_name": "IT & Software"
    },
    {
        "description": "Microsoft Office 365 licenses for 50 users",
        "vendor": "Microsoft Corporation",
        "amount": 3500.00,
        "expected_code": "5900",
        "expected_name": "IT & Software"
    },
    {
        "description": "AWS cloud hosting services",
        "vendor": "Amazon Web Services",
        "amount": 1800.00,
        "expected_code": "5900",
        "expected_name": "IT & Software"
    },

    # Marketing & Advertising
    {
        "description": "Facebook advertising campaign for Q1",
        "vendor": "Meta Platforms",
        "amount": 5000.00,
        "expected_code": "5700",
        "expected_name": "Marketing & Advertising"
    },
    {
        "description": "LinkedIn sponsored posts and ads",
        "vendor": "LinkedIn Corporation",
        "amount": 2500.00,
        "expected_code": "5700",
        "expected_name": "Marketing & Advertising"
    },
    {
        "description": "Google Ads campaign spend",
        "vendor": "Google Ads",
        "amount": 4200.00,
        "expected_code": "5700",
        "expected_name": "Marketing & Advertising"
    },

    # Office Supplies & Stationery
    {
        "description": "Office stationery and supplies",
        "vendor": "Office Depot",
        "amount": 850.00,
        "expected_code": "5500",
        "expected_name": "Office Supplies"
    },
    {
        "description": "Printer paper and ink cartridges",
        "vendor": "Staples",
        "amount": 320.00,
        "expected_code": "5500",
        "expected_name": "Office Supplies"
    },

    # Professional Fees
    {
        "description": "Legal consultation fees for contract review",
        "vendor": "Al Tamimi & Company",
        "amount": 8000.00,
        "expected_code": "5600",
        "expected_name": "Professional Fees"
    },
    {
        "description": "Audit services for FY 2024",
        "vendor": "Deloitte Middle East",
        "amount": 15000.00,
        "expected_code": "5600",
        "expected_name": "Professional Fees"
    },
    {
        "description": "Management consulting advisory services",
        "vendor": "McKinsey & Company",
        "amount": 25000.00,
        "expected_code": "5600",
        "expected_name": "Professional Fees"
    },

    # Travel & Entertainment
    {
        "description": "Business flight tickets to London",
        "vendor": "Emirates Airlines",
        "amount": 3500.00,
        "expected_code": "5800",
        "expected_name": "Travel & Entertainment"
    },
    {
        "description": "Hotel accommodation for conference",
        "vendor": "Marriott International",
        "amount": 1200.00,
        "expected_code": "5800",
        "expected_name": "Travel & Entertainment"
    },

    # Insurance
    {
        "description": "Professional liability insurance premium",
        "vendor": "AXA Insurance",
        "amount": 6000.00,
        "expected_code": "6100",
        "expected_name": "Insurance"
    },

    # Bank Charges
    {
        "description": "Bank transaction fees and charges",
        "vendor": "Emirates NBD",
        "amount": 250.00,
        "expected_code": "6200",
        "expected_name": "Bank Charges"
    }
]

def test_classification(description: str, vendor: str, amount: float, invoice_id: str) -> Dict:
    """Test a single classification"""
    payload = {
        "tenant_id": TENANT_ID,
        "invoice_id": invoice_id,
        "vendor_name": vendor,
        "transaction_type": "AP",
        "lines": [
            {
                "line_number": 1,
                "description": description,
                "amount": amount,
                "quantity": 1.0
            }
        ]
    }

    start_time = time.time()
    response = requests.post(API_URL, json=payload)
    response_time = (time.time() - start_time) * 1000

    if response.status_code == 200:
        result = response.json()
        suggestion = result['suggestions'][0]
        return {
            "success": True,
            "account_code": suggestion['account_code'],
            "account_name": suggestion['account_name'],
            "confidence": suggestion['confidence_score'],
            "reasoning": suggestion['reasoning'],
            "response_time_ms": response_time,
            "api_response_time_ms": result['processing_time_ms']
        }
    else:
        return {
            "success": False,
            "error": response.text,
            "response_time_ms": response_time
        }

def run_comprehensive_test():
    """Run comprehensive test suite"""
    print("=" * 80)
    print("AIRP v2.0 - AI Classification Comprehensive Test")
    print("=" * 80)
    print(f"Started at: {datetime.now().isoformat()}")
    print(f"Total test cases: {len(TEST_TRANSACTIONS)}")
    print("=" * 80)
    print()

    results = []
    correct = 0
    total = len(TEST_TRANSACTIONS)
    total_response_time = 0

    for i, test in enumerate(TEST_TRANSACTIONS, 1):
        print(f"Test {i}/{total}: {test['description'][:50]}...")

        result = test_classification(
            test['description'],
            test['vendor'],
            test['amount'],
            f"test-{i:03d}"
        )

        if result['success']:
            is_correct = result['account_code'] == test['expected_code']
            if is_correct:
                correct += 1
                status = "[OK] CORRECT"
            else:
                status = "[X] WRONG"

            print(f"  {status}")
            print(f"  Expected: {test['expected_code']} ({test['expected_name']})")
            print(f"  Got:      {result['account_code']} ({result['account_name']})")
            print(f"  Confidence: {result['confidence']:.2%}")
            print(f"  Response Time: {result['response_time_ms']:.0f}ms")

            # Extract method from reasoning
            if "LLM Analysis" in result['reasoning']:
                method = "LLM"
            elif "Keyword-based" in result['reasoning']:
                method = "Rule"
            else:
                method = "Unknown"
            print(f"  Method: {method}")

            results.append({
                "test_id": i,
                "description": test['description'],
                "expected_code": test['expected_code'],
                "actual_code": result['account_code'],
                "correct": is_correct,
                "confidence": result['confidence'],
                "response_time_ms": result['response_time_ms'],
                "method": method
            })

            total_response_time += result['response_time_ms']
        else:
            print(f"  [X] ERROR: {result['error']}")
            results.append({
                "test_id": i,
                "description": test['description'],
                "error": result['error'],
                "correct": False
            })

        print()

        # Small delay to avoid rate limiting
        time.sleep(1)

    # Summary
    print("=" * 80)
    print("TEST SUMMARY")
    print("=" * 80)
    accuracy = (correct / total) * 100
    avg_response_time = total_response_time / total

    print(f"Total Tests:        {total}")
    print(f"Correct:            {correct}")
    print(f"Incorrect:          {total - correct}")
    print(f"Accuracy:           {accuracy:.1f}%")
    print(f"Avg Response Time:  {avg_response_time:.0f}ms")
    print()

    # Method breakdown
    llm_count = sum(1 for r in results if r.get('method') == 'LLM')
    rule_count = sum(1 for r in results if r.get('method') == 'Rule')
    print(f"LLM Classifications: {llm_count}")
    print(f"Rule-based:          {rule_count}")
    print()

    # Confidence analysis
    confidences = [r['confidence'] for r in results if 'confidence' in r]
    if confidences:
        avg_confidence = sum(confidences) / len(confidences)
        print(f"Avg Confidence:     {avg_confidence:.1%}")
        print(f"Min Confidence:     {min(confidences):.1%}")
        print(f"Max Confidence:     {max(confidences):.1%}")

    print("=" * 80)

    # Save results to JSON
    output_file = "test-results.json"
    with open(output_file, 'w') as f:
        json.dump({
            "timestamp": datetime.now().isoformat(),
            "total_tests": total,
            "correct": correct,
            "accuracy": accuracy,
            "avg_response_time_ms": avg_response_time,
            "llm_count": llm_count,
            "rule_count": rule_count,
            "results": results
        }, f, indent=2)

    print(f"\nDetailed results saved to: {output_file}")

    # Status
    if accuracy >= 90:
        print("\n[EXCELLENT!] Classification accuracy is 90%+")
    elif accuracy >= 75:
        print("\n[GOOD!] Classification accuracy is 75%+")
    elif accuracy >= 60:
        print("\n[FAIR] Classification accuracy needs improvement")
    else:
        print("\n[POOR] Significant accuracy issues detected")

if __name__ == "__main__":
    run_comprehensive_test()
