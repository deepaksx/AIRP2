# AIRP v2.0 - Reporting APIs Quick Reference

## All Implemented Endpoints

### Base URL
```
http://localhost:3008
```

---

## 1. Vendor Ledger
```bash
GET /reports/vendor-ledger?tenant_id={UUID}&vendor_id={UUID}
```

**Example:**
```bash
curl "http://localhost:3008/reports/vendor-ledger?tenant_id=00000000-0000-0000-0000-000000000001&vendor_id=20000000-0000-0000-0000-000000000001"
```

---

## 2. Customer Ledger
```bash
GET /reports/customer-ledger?tenant_id={UUID}&customer_id={UUID}
```

**Example:**
```bash
curl "http://localhost:3008/reports/customer-ledger?tenant_id=00000000-0000-0000-0000-000000000001&customer_id=30000000-0000-0000-0000-000000000001"
```

---

## 3. Account Balances
```bash
GET /reports/account-balances?tenant_id={UUID}
```

**Example:**
```bash
curl "http://localhost:3008/reports/account-balances?tenant_id=00000000-0000-0000-0000-000000000001"
```

---

## 4. Income Statement
```bash
GET /reports/income-statement?tenant_id={UUID}&start_date={YYYY-MM-DD}&end_date={YYYY-MM-DD}
```

**Example:**
```bash
curl "http://localhost:3008/reports/income-statement?tenant_id=00000000-0000-0000-0000-000000000001&start_date=2024-01-01&end_date=2024-12-31"
```

---

## 5. Balance Sheet
```bash
GET /reports/balance-sheet?tenant_id={UUID}&as_of_date={YYYY-MM-DD}
```

**Example:**
```bash
curl "http://localhost:3008/reports/balance-sheet?tenant_id=00000000-0000-0000-0000-000000000001&as_of_date=2024-12-31"
```

---

## 6. Cash Flow Statement
```bash
GET /reports/cash-flow?tenant_id={UUID}&start_date={YYYY-MM-DD}&end_date={YYYY-MM-DD}
```

**Example:**
```bash
curl "http://localhost:3008/reports/cash-flow?tenant_id=00000000-0000-0000-0000-000000000001&start_date=2024-01-01&end_date=2024-12-31"
```

---

## Existing Endpoints (Still Available)

### Trial Balance
```bash
GET /reports/trial-balance?tenant_id={UUID}&period_end_date={YYYY-MM-DD}
```

### AP Aging
```bash
GET /reports/aging/ap?tenant_id={UUID}
```

### AR Aging
```bash
GET /reports/aging/ar?tenant_id={UUID}
```

---

## Files Modified

1. **C:\Dev\AIRP2\services\reporting-service\src\reporting.service.ts**
2. **C:\Dev\AIRP2\services\reporting-service\src\reporting.controller.ts**

---

## Test Scripts

**PowerShell:**
```powershell
.\test-reporting-apis.ps1
```

**Bash:**
```bash
bash test-reporting-apis.sh
```

---

## Start Service

```bash
cd C:\Dev\AIRP2\services\reporting-service
npm run start:dev
```

---

## Documentation

- **Full API Docs:** `REPORTING_API_IMPLEMENTATION.md`
- **SQL Queries:** `SQL_QUERIES_REFERENCE.md`
- **Summary:** `IMPLEMENTATION_SUMMARY.md`
- **Quick Ref:** This file

---

**Status:** ✓ All 6 endpoints implemented and tested
**Build:** ✓ Successful
**Port:** 3008
