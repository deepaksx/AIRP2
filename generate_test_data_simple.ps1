# Simple Test Data Generator for Universal Journal
# Generates 100+ transactions using SQL

Write-Host "Generating comprehensive test data..." -ForegroundColor Cyan

docker exec -i airp-postgres psql -U airp_admin -d airp_master << 'EOF'

-- Generate 102 test transactions (30 AP + 30 AR + 20 Payments + 12 Payroll + 10 Adjustments)

DO $$
DECLARE
    v_tenant_id UUID := '00000000-0000-0000-0000-000000000001';
    v_entry_id UUID;
    v_line_id UUID;
    v_account_ap UUID;
    v_account_ar UUID;
    v_account_cash UUID;
    v_account_expense UUID;
    v_account_revenue UUID;
    v_account_salary UUID;
    v_account_insurance UUID;
    v_account_prepaid UUID;
    v_vendors UUID[];
    v_customers UUID[];
    v_vendor_id UUID;
    v_customer_id UUID;
    v_invoice_date DATE;
    v_due_date DATE;
    v_amount NUMERIC;
    v_invoice_number TEXT;
    v_entry_number TEXT;
    v_metadata JSONB;
    i INTEGER;
BEGIN
    -- Get account IDs
    SELECT account_id INTO v_account_ap FROM chart_of_accounts WHERE account_code = '2100' AND tenant_id = v_tenant_id;
    SELECT account_id INTO v_account_ar FROM chart_of_accounts WHERE account_code = '1200' AND tenant_id = v_tenant_id;
    SELECT account_id INTO v_account_cash FROM chart_of_accounts WHERE account_code = '1010' AND tenant_id = v_tenant_id;
    SELECT account_id INTO v_account_expense FROM chart_of_accounts WHERE account_code = '5100' AND tenant_id = v_tenant_id;
    SELECT account_id INTO v_account_revenue FROM chart_of_accounts WHERE account_code = '4000' AND tenant_id = v_tenant_id;
    SELECT account_id INTO v_account_salary FROM chart_of_accounts WHERE account_code = '5000' AND tenant_id = v_tenant_id;
    SELECT account_id INTO v_account_insurance FROM chart_of_accounts WHERE account_code = '5400' AND tenant_id = v_tenant_id;
    SELECT account_id INTO v_account_prepaid FROM chart_of_accounts WHERE account_code = '1300' AND tenant_id = v_tenant_id;

    -- Get vendors and customers
    SELECT ARRAY_AGG(vendor_id) INTO v_vendors FROM vendors WHERE tenant_id = v_tenant_id;
    SELECT ARRAY_AGG(customer_id) INTO v_customers FROM customers WHERE tenant_id = v_tenant_id;

    RAISE NOTICE 'Creating 30 AP Invoices...';

    -- Generate 30 AP Invoices
    FOR i IN 1..30 LOOP
        v_vendor_id := v_vendors[1 + (i % array_length(v_vendors, 1))];
        v_invoice_date := CURRENT_DATE - (90 - (i * 3))::INTEGER;
        v_due_date := v_invoice_date + 30;
        v_amount := 1000 + (i * 100);
        v_invoice_number := 'INV-AP-2025-' || LPAD(i::TEXT, 4, '0');
        v_entry_number := 'JE-AP-2025-' || LPAD(i::TEXT, 4, '0');

        v_metadata := jsonb_build_object(
            'source_type', 'ap_invoice',
            'invoice_number', v_invoice_number,
            'invoice_date', v_invoice_date::TEXT,
            'due_date', v_due_date::TEXT,
            'payment_terms', 'Net 30',
            'payment_status', CASE WHEN i % 3 = 0 THEN 'paid' WHEN i % 5 = 0 THEN 'partial' ELSE 'unpaid' END,
            'total_amount', v_amount,
            'amount_paid', CASE WHEN i % 3 = 0 THEN v_amount WHEN i % 5 = 0 THEN v_amount * 0.5 ELSE 0 END,
            'amount_outstanding', CASE WHEN i % 3 = 0 THEN 0 WHEN i % 5 = 0 THEN v_amount * 0.5 ELSE v_amount END,
            'subtotal', v_amount / 1.05,
            'tax_amount', v_amount * 0.05 / 1.05,
            'currency', 'AED'
        );

        v_entry_id := gen_random_uuid();
        INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, posting_date, entry_type, source_type, description, total_debit, total_credit, status)
        VALUES (v_entry_id, v_tenant_id, v_entry_number, v_invoice_date, v_invoice_date, 'AP Invoice', 'api', 'AP Invoice ' || v_invoice_number, v_amount, v_amount, 'posted');

        -- Dr Expense
        v_line_id := gen_random_uuid();
        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, account_id, debit_amount, credit_amount, description, metadata)
        VALUES (v_line_id, v_entry_id, v_tenant_id, v_account_expense, v_amount, 0, 'Invoice ' || v_invoice_number, '{}'::jsonb);

        -- Cr AP (with metadata)
        v_line_id := gen_random_uuid();
        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, account_id, debit_amount, credit_amount, description, dimension_1, metadata)
        VALUES (v_line_id, v_entry_id, v_tenant_id, v_account_ap, 0, v_amount, 'Invoice ' || v_invoice_number, v_vendor_id, v_metadata);
    END LOOP;

    RAISE NOTICE 'Created 30 AP Invoices';
    RAISE NOTICE 'Creating 30 AR Invoices...';

    -- Generate 30 AR Invoices
    FOR i IN 1..30 LOOP
        v_customer_id := v_customers[1 + (i % array_length(v_customers, 1))];
        v_invoice_date := CURRENT_DATE - (90 - (i * 3))::INTEGER;
        v_due_date := v_invoice_date + 30;
        v_amount := 2000 + (i * 150);
        v_invoice_number := 'INV-AR-2025-' || LPAD(i::TEXT, 4, '0');
        v_entry_number := 'JE-AR-2025-' || LPAD(i::TEXT, 4, '0');

        v_metadata := jsonb_build_object(
            'source_type', 'ar_invoice',
            'invoice_number', v_invoice_number,
            'invoice_date', v_invoice_date::TEXT,
            'due_date', v_due_date::TEXT,
            'payment_terms', 'Net 30',
            'payment_status', CASE WHEN i % 3 = 0 THEN 'paid' WHEN i % 4 = 0 THEN 'partial' ELSE 'unpaid' END,
            'total_amount', v_amount,
            'amount_paid', CASE WHEN i % 3 = 0 THEN v_amount WHEN i % 4 = 0 THEN v_amount * 0.6 ELSE 0 END,
            'amount_outstanding', CASE WHEN i % 3 = 0 THEN 0 WHEN i % 4 = 0 THEN v_amount * 0.4 ELSE v_amount END,
            'subtotal', v_amount / 1.05,
            'tax_amount', v_amount * 0.05 / 1.05,
            'currency', 'AED'
        );

        v_entry_id := gen_random_uuid();
        INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, posting_date, entry_type, source_type, description, total_debit, total_credit, status)
        VALUES (v_entry_id, v_tenant_id, v_entry_number, v_invoice_date, v_invoice_date, 'AR Invoice', 'api', 'AR Invoice ' || v_invoice_number, v_amount, v_amount, 'posted');

        -- Dr AR (with metadata)
        v_line_id := gen_random_uuid();
        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, account_id, debit_amount, credit_amount, description, dimension_2, metadata)
        VALUES (v_line_id, v_entry_id, v_tenant_id, v_account_ar, v_amount, 0, 'Invoice ' || v_invoice_number, v_customer_id, v_metadata);

        -- Cr Revenue
        v_line_id := gen_random_uuid();
        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, account_id, debit_amount, credit_amount, description, metadata)
        VALUES (v_line_id, v_entry_id, v_tenant_id, v_account_revenue, 0, v_amount, 'Invoice ' || v_invoice_number, '{}'::jsonb);
    END LOOP;

    RAISE NOTICE 'Created 30 AR Invoices';
    RAISE NOTICE 'Creating 20 Payments...';

    -- Generate 20 Payments
    FOR i IN 1..20 LOOP
        v_invoice_date := CURRENT_DATE - (60 - (i * 3))::INTEGER;
        v_amount := 1500 + (i * 200);

        IF i % 2 = 0 THEN
            -- AP Payment
            v_entry_number := 'JE-PMT-AP-2025-' || LPAD(i::TEXT, 4, '0');
            v_entry_id := gen_random_uuid();
            INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, posting_date, entry_type, source_type, description, total_debit, total_credit, status)
            VALUES (v_entry_id, v_tenant_id, v_entry_number, v_invoice_date, v_invoice_date, 'Payment', 'api', 'Vendor Payment', v_amount, v_amount, 'posted');

            v_line_id := gen_random_uuid();
            INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, account_id, debit_amount, credit_amount, description, metadata)
            VALUES (v_line_id, v_entry_id, v_tenant_id, v_account_ap, v_amount, 0, 'Payment', '{}'::jsonb);

            v_line_id := gen_random_uuid();
            INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, account_id, debit_amount, credit_amount, description, metadata)
            VALUES (v_line_id, v_entry_id, v_tenant_id, v_account_cash, 0, v_amount, 'Payment', '{}'::jsonb);
        ELSE
            -- AR Receipt
            v_entry_number := 'JE-RCT-AR-2025-' || LPAD(i::TEXT, 4, '0');
            v_entry_id := gen_random_uuid();
            INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, posting_date, entry_type, source_type, description, total_debit, total_credit, status)
            VALUES (v_entry_id, v_tenant_id, v_entry_number, v_invoice_date, v_invoice_date, 'Receipt', 'api', 'Customer Receipt', v_amount, v_amount, 'posted');

            v_line_id := gen_random_uuid();
            INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, account_id, debit_amount, credit_amount, description, metadata)
            VALUES (v_line_id, v_entry_id, v_tenant_id, v_account_cash, v_amount, 0, 'Receipt', '{}'::jsonb);

            v_line_id := gen_random_uuid();
            INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, account_id, debit_amount, credit_amount, description, metadata)
            VALUES (v_line_id, v_entry_id, v_tenant_id, v_account_ar, 0, v_amount, 'Receipt', '{}'::jsonb);
        END IF;
    END LOOP;

    RAISE NOTICE 'Created 20 Payments';
    RAISE NOTICE 'Creating 12 Payroll Entries...';

    -- Generate 12 Payroll entries
    FOR i IN 1..12 LOOP
        v_invoice_date := CURRENT_DATE - (360 - (i * 30))::INTEGER;
        v_amount := 48000;
        v_entry_number := 'JE-PAY-2024-' || LPAD(i::TEXT, 2, '0');

        v_entry_id := gen_random_uuid();
        INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, posting_date, entry_type, source_type, description, total_debit, total_credit, status)
        VALUES (v_entry_id, v_tenant_id, v_entry_number, v_invoice_date, v_invoice_date, 'Payroll', 'api', 'Monthly Payroll', v_amount, v_amount, 'posted');

        v_line_id := gen_random_uuid();
        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, account_id, debit_amount, credit_amount, description, metadata)
        VALUES (v_line_id, v_entry_id, v_tenant_id, v_account_salary, v_amount, 0, 'Payroll', '{}'::jsonb);

        v_line_id := gen_random_uuid();
        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, account_id, debit_amount, credit_amount, description, metadata)
        VALUES (v_line_id, v_entry_id, v_tenant_id, v_account_cash, 0, v_amount, 'Payroll', '{}'::jsonb);
    END LOOP;

    RAISE NOTICE 'Created 12 Payroll Entries';
    RAISE NOTICE 'Creating 10 Adjusting Entries...';

    -- Generate 10 Adjusting entries
    FOR i IN 1..10 LOOP
        v_invoice_date := CURRENT_DATE - (300 - (i * 30))::INTEGER;
        v_amount := 800 + (i * 100);
        v_entry_number := 'JE-ADJ-2024-' || LPAD(i::TEXT, 3, '0');

        v_entry_id := gen_random_uuid();
        INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, posting_date, entry_type, source_type, description, total_debit, total_credit, status)
        VALUES (v_entry_id, v_tenant_id, v_entry_number, v_invoice_date, v_invoice_date, 'Adjusting', 'api', 'Period-end Adjustment', v_amount, v_amount, 'posted');

        v_line_id := gen_random_uuid();
        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, account_id, debit_amount, credit_amount, description, metadata)
        VALUES (v_line_id, v_entry_id, v_tenant_id, v_account_insurance, v_amount, 0, 'Adjustment', '{}'::jsonb);

        v_line_id := gen_random_uuid();
        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, account_id, debit_amount, credit_amount, description, metadata)
        VALUES (v_line_id, v_entry_id, v_tenant_id, v_account_prepaid, 0, v_amount, 'Adjustment', '{}'::jsonb);
    END LOOP;

    RAISE NOTICE 'Created 10 Adjusting Entries';
    RAISE NOTICE 'Updating GL Balances...';

    -- Update GL balances
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
        balance = EXCLUDED.balance;

    REFRESH MATERIALIZED VIEW trial_balance;
    REFRESH MATERIALIZED VIEW mv_ap_aging;
    REFRESH MATERIALIZED VIEW mv_ar_aging;

    RAISE NOTICE 'GL Balances Updated and Views Refreshed';
END $$;

-- Summary
SELECT
    'Journal Entries' as item,
    COUNT(*)::TEXT as count
FROM journal_entries
UNION ALL
SELECT
    'Journal Lines' as item,
    COUNT(*)::TEXT
FROM journal_entry_lines
UNION ALL
SELECT
    'AP Invoices (view)' as item,
    COUNT(*)::TEXT
FROM vw_ap_invoices
UNION ALL
SELECT
    'AR Invoices (view)' as item,
    COUNT(*)::TEXT
FROM vw_ar_invoices
UNION ALL
SELECT
    'AP Aging Records' as item,
    COUNT(*)::TEXT
FROM mv_ap_aging
UNION ALL
SELECT
    'AR Aging Records' as item,
    COUNT(*)::TEXT
FROM mv_ar_aging;

EOF

Write-Host "`nTest data generation complete!" -ForegroundColor Green
