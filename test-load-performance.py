#!/usr/bin/env python3
"""
AIRP v2.0 - AI Classification Load & Performance Test
Tests with 100 concurrent classifications to measure performance and rate limits
"""
import json
import time
import requests
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import statistics

API_URL = "http://localhost:8001/classify"
TENANT_ID = "00000000-0000-0000-0000-000000000001"

# Sample descriptions for load testing
SAMPLE_DESCRIPTIONS = [
    ("Office rent payment", "Dubai Properties", 5000.00, "5300"),
    ("Electricity bill", "DEWA", 1200.00, "5400"),
    ("Employee salaries", "HR Dept", 25000.00, "5200"),
    ("Google Workspace subscription", "Google", 2400.00, "5900"),
    ("Facebook ads campaign", "Meta", 5000.00, "5700"),
    ("Office supplies", "Office Depot", 850.00, "5500"),
    ("Legal consultation fees", "Law Firm", 8000.00, "5600"),
    ("Flight tickets", "Emirates", 3500.00, "5800"),
    ("Insurance premium", "AXA", 6000.00, "6100"),
    ("Bank charges", "Emirates NBD", 250.00, "6200"),
]

def classify_single(test_id: int):
    """Single classification request"""
    # Rotate through sample descriptions
    desc, vendor, amount, expected = SAMPLE_DESCRIPTIONS[test_id % len(SAMPLE_DESCRIPTIONS)]

    payload = {
        "tenant_id": TENANT_ID,
        "invoice_id": f"load-{test_id:04d}",
        "vendor_name": vendor,
        "transaction_type": "AP",
        "lines": [
            {
                "line_number": 1,
                "description": f"{desc} - Test #{test_id}",
                "amount": amount,
                "quantity": 1.0
            }
        ]
    }

    start_time = time.time()

    try:
        response = requests.post(API_URL, json=payload, timeout=60)
        response_time = (time.time() - start_time) * 1000

        if response.status_code == 200:
            result = response.json()
            suggestion = result['suggestions'][0]

            return {
                "test_id": test_id,
                "success": True,
                "account_code": suggestion['account_code'],
                "expected_code": expected,
                "correct": suggestion['account_code'] == expected,
                "confidence": suggestion['confidence_score'],
                "response_time_ms": response_time,
                "status_code": 200
            }
        elif response.status_code == 429:  # Rate limit
            return {
                "test_id": test_id,
                "success": False,
                "error": "Rate limit exceeded",
                "response_time_ms": response_time,
                "status_code": 429
            }
        else:
            return {
                "test_id": test_id,
                "success": False,
                "error": f"HTTP {response.status_code}",
                "response_time_ms": response_time,
                "status_code": response.status_code
            }

    except requests.Timeout:
        return {
            "test_id": test_id,
            "success": False,
            "error": "Timeout (>60s)",
            "response_time_ms": 60000,
            "status_code": 0
        }
    except Exception as e:
        return {
            "test_id": test_id,
            "success": False,
            "error": str(e)[:100],
            "response_time_ms": (time.time() - start_time) * 1000,
            "status_code": 0
        }

def run_load_test(total_requests=100, max_workers=10):
    """Run load test with concurrent requests"""
    print("=" * 80)
    print("AIRP v2.0 - AI Classification Load & Performance Test")
    print("=" * 80)
    print(f"Started at: {datetime.now().isoformat()}")
    print(f"Total requests: {total_requests}")
    print(f"Concurrent workers: {max_workers}")
    print("=" * 80)
    print()

    results = []
    start_time = time.time()

    # Execute requests concurrently
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_id = {executor.submit(classify_single, i): i for i in range(1, total_requests + 1)}

        completed = 0
        for future in as_completed(future_to_id):
            completed += 1
            result = future.result()
            results.append(result)

            if completed % 10 == 0:
                print(f"Progress: {completed}/{total_requests} requests completed...")

    total_time = time.time() - start_time

    print(f"\nAll {total_requests} requests completed in {total_time:.1f} seconds")
    print()

    # Analysis
    successful = [r for r in results if r['success']]
    failed = [r for r in results if not r['success']]
    rate_limited = [r for r in results if r.get('status_code') == 429]
    timeouts = [r for r in results if 'Timeout' in r.get('error', '')]
    correct = [r for r in successful if r.get('correct')]

    response_times = [r['response_time_ms'] for r in successful]

    print("=" * 80)
    print("LOAD TEST RESULTS")
    print("=" * 80)
    print(f"Total Requests:       {total_requests}")
    print(f"Successful:           {len(successful)} ({len(successful)/total_requests*100:.1f}%)")
    print(f"Failed:               {len(failed)} ({len(failed)/total_requests*100:.1f}%)")
    print(f"Rate Limited (429):   {len(rate_limited)}")
    print(f"Timeouts:             {len(timeouts)}")
    print()

    if correct:
        print(f"Accuracy:             {len(correct)}/{len(successful)} ({len(correct)/len(successful)*100:.1f}%)")
    print()

    print(f"Total Time:           {total_time:.2f}s")
    print(f"Requests/Second:      {total_requests/total_time:.2f}")
    print()

    if response_times:
        print("Response Time Statistics:")
        print(f"  Min:                {min(response_times):.0f}ms")
        print(f"  Max:                {max(response_times):.0f}ms")
        print(f"  Average:            {statistics.mean(response_times):.0f}ms")
        print(f"  Median:             {statistics.median(response_times):.0f}ms")
        print(f"  Std Dev:            {statistics.stdev(response_times):.0f}ms" if len(response_times) > 1 else "")
        print(f"  P95:                {sorted(response_times)[int(len(response_times)*0.95)]:.0f}ms" if len(response_times) > 5 else "")
        print(f"  P99:                {sorted(response_times)[int(len(response_times)*0.99)]:.0f}ms" if len(response_times) > 10 else "")

    print()

    # Cost estimation (Claude 3.5 Sonnet pricing)
    # Input: $3 per 1M tokens, Output: $15 per 1M tokens
    # Rough estimate: ~500 input tokens + ~200 output tokens per request
    if successful:
        estimated_input_tokens = len(successful) * 500
        estimated_output_tokens = len(successful) * 200
        input_cost = (estimated_input_tokens / 1_000_000) * 3
        output_cost = (estimated_output_tokens / 1_000_000) * 15
        total_cost = input_cost + output_cost

        print("Cost Estimation (Claude 3.5 Sonnet):")
        print(f"  Estimated Input Tokens:  {estimated_input_tokens:,}")
        print(f"  Estimated Output Tokens: {estimated_output_tokens:,}")
        print(f"  Estimated Cost:          ${total_cost:.4f}")
        print(f"  Cost per Transaction:    ${total_cost/len(successful):.6f}")

        # Monthly extrapolation
        monthly_transactions = 15000  # Assume 15K transactions/month
        monthly_cost = (total_cost / len(successful)) * monthly_transactions
        print(f"\n  Monthly Cost (15K tx):   ${monthly_cost:.2f}")

    print("=" * 80)

    # Error breakdown
    if failed:
        print("\nError Breakdown:")
        error_types = {}
        for r in failed:
            error_key = r.get('error', 'Unknown')[:50]
            error_types[error_key] = error_types.get(error_key, 0) + 1

        for error, count in sorted(error_types.items(), key=lambda x: x[1], reverse=True):
            print(f"  {error}: {count} occurrences")
        print()

    # Save results
    output_file = "load-test-results.json"
    with open(output_file, 'w') as f:
        json.dump({
            "timestamp": datetime.now().isoformat(),
            "total_requests": total_requests,
            "successful": len(successful),
            "failed": len(failed),
            "rate_limited": len(rate_limited),
            "timeouts": len(timeouts),
            "total_time_seconds": total_time,
            "requests_per_second": total_requests / total_time,
            "response_time_stats": {
                "min_ms": min(response_times) if response_times else 0,
                "max_ms": max(response_times) if response_times else 0,
                "avg_ms": statistics.mean(response_times) if response_times else 0,
                "median_ms": statistics.median(response_times) if response_times else 0,
            },
            "results": results
        }, f, indent=2)

    print(f"Detailed results saved to: {output_file}")

    # Status
    success_rate = len(successful) / total_requests * 100
    if success_rate >= 95 and not rate_limited:
        print("\n[EXCELLENT!] System handles load very well (95%+ success, no rate limits)")
    elif success_rate >= 90:
        print("\n[GOOD!] System performs well under load (90%+ success)")
    elif success_rate >= 75:
        print("\n[FAIR] Some performance issues under load")
    else:
        print("\n[POOR] Significant issues under load - needs optimization")

    if rate_limited:
        print(f"\n[WARNING] {len(rate_limited)} requests hit rate limits!")
        print("Consider implementing:")
        print("  - Request batching")
        print("  - Exponential backoff retry")
        print("  - Queue-based processing")
        print("  - Higher API tier from Anthropic")

if __name__ == "__main__":
    # Run load test with 100 requests, 10 concurrent workers
    run_load_test(total_requests=100, max_workers=10)
