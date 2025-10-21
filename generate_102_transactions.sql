-- Generate 102 comprehensive test transactions for Universal Journal

DO $$
DECLARE
    v_tenant_id UUID := '00000000-0000-0000-0000-000000000001';
    v_entry_id UUID;
    v_account_ap UUID;
    v_account_ar UUID;
    v_account_cash UUID;
    v_account_expense UUID;
    v_account_revenue UUID;
    v_vendors UUID[];
    v_customers UUID[];
    v_vendor_id UUID;
    v_customer_id UUID;
    v_date DATE;
    v_amount NUMERIC;
    v_metadata JSONB;
    i INTEGER;
BEGIN
    -- Get account IDs
    SELECT account_id INTO v_account_ap FROM chart_of_accounts WHERE account_code = '2100' AND tenant_id = v_tenant_id;
    SELECT account_id INTO v_account_ar FROM chart_of_accounts WHERE account_code = '1200' AND tenant_id = v_tenant_id;
    SELECT account_id INTO v_account_cash FROM chart_of_accounts WHERE account_code = '1010' AND tenant_id = v_tenant_id;
    SELECT account_id INTO v_account_expense FROM chart_of_accounts WHERE account_code = '5100' AND tenant_id = v_tenant_id;
    SELECT account_id INTO v_account_revenue FROM chart_of_accounts WHERE account_code = '4000' AND tenant_id = v_tenant_id;

    SELECT ARRAY_AGG(vendor_id) INTO v_vendors FROM vendors WHERE tenant_id = v_tenant_id;
    SELECT ARRAY_AGG(customer_id) INTO v_customers FROM customers WHERE tenant_id = v_tenant_id;

    RAISE NOTICE 'Creating 30 AP Invoices...';

    -- 30 AP Invoices
    FOR i IN 1..30 LOOP
        v_vendor_id := v_vendors[1 + (i % array_length(v_vendors, 1))];
        v_date := CURRENT_DATE - (90 - i * 3)::INTEGER;
        v_amount := 1000 + i * 100;

        v_metadata := jsonb_build_object(
            'source_type', 'ap_invoice',
            'invoice_number', 'INV-AP-2025-' || LPAD(i::TEXT, 4, '0'),
            'invoice_date', v_date::TEXT,
            'due_date', (v_date + 30)::TEXT,
            'payment_terms', 'Net 30',
            'payment_status', CASE WHEN i % 3 = 0 THEN 'paid' ELSE 'unpaid' END,
            'total_amount', v_amount,
            'amount_outstanding', CASE WHEN i % 3 = 0 THEN 0 ELSE v_amount END,
            'currency', 'AED'
        );

        v_entry_id := gen_random_uuid();
        INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, posting_date, entry_type, source_type, description, total_debit, total_credit, status)
        VALUES (v_entry_id, v_tenant_id, 'JE-AP-' || i, v_date, v_date, 'AP Invoice', 'api', 'AP Invoice', v_amount, v_amount, 'posted');

        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description, metadata)
        VALUES (gen_random_uuid(), v_entry_id, v_tenant_id, 1, v_account_expense, v_amount, 0, 'Expense', '{}'::jsonb);

        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description, dimension_1, metadata)
        VALUES (gen_random_uuid(), v_entry_id, v_tenant_id, 2, v_account_ap, 0, v_amount, 'AP', v_vendor_id, v_metadata);
    END LOOP;

    RAISE NOTICE 'Created 30 AP Invoices';
    RAISE NOTICE 'Creating 30 AR Invoices...';

    -- 30 AR Invoices
    FOR i IN 1..30 LOOP
        v_customer_id := v_customers[1 + (i % array_length(v_customers, 1))];
        v_date := CURRENT_DATE - (90 - i * 3)::INTEGER;
        v_amount := 2000 + i * 150;

        v_metadata := jsonb_build_object(
            'source_type', 'ar_invoice',
            'invoice_number', 'INV-AR-2025-' || LPAD(i::TEXT, 4, '0'),
            'invoice_date', v_date::TEXT,
            'due_date', (v_date + 30)::TEXT,
            'payment_terms', 'Net 30',
            'payment_status', CASE WHEN i % 3 = 0 THEN 'paid' ELSE 'unpaid' END,
            'total_amount', v_amount,
            'amount_outstanding', CASE WHEN i % 3 = 0 THEN 0 ELSE v_amount END,
            'currency', 'AED'
        );

        v_entry_id := gen_random_uuid();
        INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, posting_date, entry_type, source_type, description, total_debit, total_credit, status)
        VALUES (v_entry_id, v_tenant_id, 'JE-AR-' || i, v_date, v_date, 'AR Invoice', 'api', 'AR Invoice', v_amount, v_amount, 'posted');

        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description, dimension_2, metadata)
        VALUES (gen_random_uuid(), v_entry_id, v_tenant_id, 1, v_account_ar, v_amount, 0, 'AR', v_customer_id, v_metadata);

        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description, metadata)
        VALUES (gen_random_uuid(), v_entry_id, v_tenant_id, 2, v_account_revenue, 0, v_amount, 'Revenue', '{}'::jsonb);
    END LOOP;

    RAISE NOTICE 'Created 30 AR Invoices';
    RAISE NOTICE 'Creating 20 Payments...';

    -- 20 Payments
    FOR i IN 1..20 LOOP
        v_date := CURRENT_DATE - (60 - i * 3)::INTEGER;
        v_amount := 1500 + i * 200;
        v_entry_id := gen_random_uuid();

        IF i % 2 = 0 THEN
            INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, posting_date, entry_type, source_type, description, total_debit, total_credit, status)
            VALUES (v_entry_id, v_tenant_id, 'JE-PMT-' || i, v_date, v_date, 'Payment', 'api', 'Vendor Payment', v_amount, v_amount, 'posted');

            INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
            VALUES (gen_random_uuid(), v_entry_id, v_tenant_id, 1, v_account_ap, v_amount, 0, 'Payment');

            INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
            VALUES (gen_random_uuid(), v_entry_id, v_tenant_id, 2, v_account_cash, 0, v_amount, 'Cash');
        ELSE
            INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, posting_date, entry_type, source_type, description, total_debit, total_credit, status)
            VALUES (v_entry_id, v_tenant_id, 'JE-RCT-' || i, v_date, v_date, 'Receipt', 'api', 'Customer Receipt', v_amount, v_amount, 'posted');

            INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
            VALUES (gen_random_uuid(), v_entry_id, v_tenant_id, 1, v_account_cash, v_amount, 0, 'Cash');

            INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
            VALUES (gen_random_uuid(), v_entry_id, v_tenant_id, 2, v_account_ar, 0, v_amount, 'Receipt');
        END IF;
    END LOOP;

    RAISE NOTICE 'Created 20 Payments';
    RAISE NOTICE 'Creating 22 more transactions...';

    -- 22 Additional transactions
    FOR i IN 1..22 LOOP
        v_date := CURRENT_DATE - (300 - i * 13)::INTEGER;
        v_amount := 5000 + i * 500;
        v_entry_id := gen_random_uuid();

        INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, posting_date, entry_type, source_type, description, total_debit, total_credit, status)
        VALUES (v_entry_id, v_tenant_id, 'JE-MISC-' || i, v_date, v_date, 'General', 'api', 'Miscellaneous', v_amount, v_amount, 'posted');

        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
        VALUES (gen_random_uuid(), v_entry_id, v_tenant_id, 1, v_account_expense, v_amount, 0, 'Expense');

        INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
        VALUES (gen_random_uuid(), v_entry_id, v_tenant_id, 2, v_account_cash, 0, v_amount, 'Cash');
    END LOOP;

    RAISE NOTICE 'Created 22 additional transactions';
    RAISE NOTICE 'Updating GL balances...';

    -- Update GL balances
    INSERT INTO gl_balances (tenant_id, account_id, fiscal_year, fiscal_period, currency, debit_amount, credit_amount, balance)
    SELECT jel.tenant_id, jel.account_id, EXTRACT(YEAR FROM je.entry_date)::INTEGER, EXTRACT(MONTH FROM je.entry_date)::INTEGER, 'AED',
           SUM(jel.debit_amount), SUM(jel.credit_amount), SUM(jel.debit_amount) - SUM(jel.credit_amount)
    FROM journal_entry_lines jel
    JOIN journal_entries je ON jel.entry_id = je.entry_id
    WHERE je.status = 'posted'
    GROUP BY jel.tenant_id, jel.account_id, EXTRACT(YEAR FROM je.entry_date), EXTRACT(MONTH FROM je.entry_date)
    ON CONFLICT (tenant_id, account_id, fiscal_year, fiscal_period, currency)
    DO UPDATE SET debit_amount = EXCLUDED.debit_amount, credit_amount = EXCLUDED.credit_amount, balance = EXCLUDED.balance;

    RAISE NOTICE 'Refreshing materialized views...';

    REFRESH MATERIALIZED VIEW trial_balance;
    REFRESH MATERIALIZED VIEW mv_ap_aging;
    REFRESH MATERIALIZED VIEW mv_ar_aging;

    RAISE NOTICE '';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'TEST DATA GENERATION COMPLETE!';
    RAISE NOTICE '102 transactions created successfully';
    RAISE NOTICE '============================================';
END $$;

-- Summary Report
SELECT '============================================' as divider
UNION ALL SELECT 'SUMMARY REPORT'
UNION ALL SELECT '============================================'
UNION ALL SELECT ''
UNION ALL SELECT 'Item                    | Count'
UNION ALL SELECT '------------------------+-------'
UNION ALL SELECT 'Journal Entries         | ' || COUNT(*)::TEXT FROM journal_entries
UNION ALL SELECT 'Journal Lines           | ' || COUNT(*)::TEXT FROM journal_entry_lines
UNION ALL SELECT 'AP Invoices (view)      | ' || COUNT(*)::TEXT FROM vw_ap_invoices
UNION ALL SELECT 'AR Invoices (view)      | ' || COUNT(*)::TEXT FROM vw_ar_invoices
UNION ALL SELECT 'AP Aging (unpaid)       | ' || COUNT(*)::TEXT FROM mv_ap_aging
UNION ALL SELECT 'AR Aging (unpaid)       | ' || COUNT(*)::TEXT FROM mv_ar_aging
UNION ALL SELECT ''
UNION ALL SELECT '============================================'
UNION ALL SELECT 'Ready for testing!';
