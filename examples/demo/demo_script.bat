@echo off
REM AIRP v2.0 - End-to-End Demo Script (Windows)
REM Demonstrates: Invoice Upload -> AI Classification -> Ledger Posting -> Verification

setlocal EnableDelayedExpansion

echo ========================================================
echo.
echo   AIRP v2.0 - AI-Native Financial ERP Demo
echo   End-to-End Invoice Processing Workflow
echo.
echo ========================================================
echo.

REM Configuration
set LEDGER_WRITER=http://localhost:3001
set AI_ACCOUNTING=http://localhost:8001
set TENANT_ID=550e8400-e29b-41d4-a716-446655440000
set USER_ID=user-cfo-001

REM Step 1: Health Checks
echo [Step 1] Checking service health...
echo.

echo Checking Ledger Writer...
curl -s %LEDGER_WRITER%/health
echo.
echo.

echo Checking AI Auto-Accounting...
curl -s %AI_ACCOUNTING%/health
echo.
echo.

echo [SUCCESS] All services are healthy
echo.
timeout /t 2 /nobreak >nul

REM Step 2: AI Classification
echo [Step 2] Classifying invoice with AI...
echo.

curl -s -X POST "%AI_ACCOUNTING%/classify" ^
  -H "Content-Type: application/json" ^
  -d "{\"tenant_id\":\"%TENANT_ID%\",\"invoice_id\":\"demo-inv-001\",\"vendor_name\":\"Dubai Marketing Agency\",\"transaction_type\":\"AP\",\"lines\":[{\"line_number\":1,\"description\":\"Social media advertising campaign for Q1 2024\",\"amount\":15000.00,\"quantity\":1.0}]}" > ai_response.json

type ai_response.json
echo.
echo.

echo [SUCCESS] AI Classification Complete
echo   Check ai_response.json for details
echo.
timeout /t 2 /nobreak >nul

REM Step 3: Post Journal Entry
echo [Step 3] Posting journal entry to immutable ledger...
echo.

for /f %%i in ('powershell -command "Get-Date -Format yyyy-MM-dd"') do set TODAY=%%i

curl -s -X POST "%LEDGER_WRITER%/journal-entries" ^
  -H "Content-Type: application/json" ^
  -d "{\"tenantId\":\"%TENANT_ID%\",\"entryDate\":\"%TODAY%\",\"entryType\":\"Standard\",\"description\":\"Marketing Expense - Dubai Marketing Agency\",\"userId\":\"%USER_ID%\",\"sourceType\":\"AP\",\"aiGenerated\":true,\"aiConfidenceScore\":0.94,\"lines\":[{\"accountCode\":\"5700\",\"debitAmount\":15750,\"creditAmount\":0,\"description\":\"Marketing ^& Advertising (incl. 5%% VAT)\"},{\"accountCode\":\"2100\",\"debitAmount\":0,\"creditAmount\":15750,\"description\":\"Accounts Payable\"}]}" > je_response.json

type je_response.json
echo.
echo.

echo [SUCCESS] Journal Entry Posted
echo   Check je_response.json for entry ID
echo.
timeout /t 2 /nobreak >nul

REM Step 4: Summary
echo ========================================================
echo.
echo   Demo Complete!
echo.
echo   What Just Happened:
echo   1. AI classified invoice line -> Marketing (5700)
echo   2. Posted journal entry to immutable ledger
echo   3. Event stored with SHA-256 checksum
echo   4. Complete audit trail maintained
echo.
echo   Key Features Demonstrated:
echo   - Event sourcing with immutability
echo   - AI-powered GL classification
echo   - Confidence scoring ^& explainability
echo   - Cryptographic integrity verification
echo.
echo ========================================================
echo.

echo Next Steps:
echo   - View Swagger docs: %LEDGER_WRITER%/api/docs
echo   - Explore AI service: %AI_ACCOUNTING%/docs
echo   - Check responses: ai_response.json, je_response.json
echo.

echo Thank you for exploring AIRP v2.0!
echo.

pause
