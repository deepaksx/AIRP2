INSERT INTO tenants (tenant_id, tenant_name, tenant_code, base_currency, timezone, fiscal_year_end)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'Demo Company LLC', 'DEMO001', 'AED', 'Asia/Dubai', 12)
ON CONFLICT (tenant_id) DO NOTHING;

INSERT INTO chart_of_accounts (account_id, tenant_id, account_code, account_name, account_type, parent_account_id, is_active)
VALUES
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '1000', 'Cash', 'asset', NULL, true),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '1200', 'Accounts Receivable', 'asset', NULL, true),
    ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', '2100', 'Accounts Payable', 'liability', NULL, true),
    ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', '4000', 'Revenue - Product Sales', 'revenue', NULL, true),
    ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', '5100', 'Cost of Goods Sold', 'expense', NULL, true),
    ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000001', '5500', 'Office Supplies', 'expense', NULL, true),
    ('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000001', '5900', 'IT & Software', 'expense', NULL, true)
ON CONFLICT (account_id) DO NOTHING;

INSERT INTO vendors (vendor_id, tenant_id, vendor_code, vendor_name, email, default_currency, payment_terms_days, status)
VALUES
    ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'VEN001', 'ABC Suppliers LLC', 'supplier@abc.ae', 'AED', 30, 'active')
ON CONFLICT (vendor_id) DO NOTHING;

INSERT INTO customers (customer_id, tenant_id, customer_code, customer_name, email, default_currency, payment_terms_days, credit_limit, status)
VALUES
    ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'CUS001', 'XYZ Trading LLC', 'customer@xyz.ae', 'AED', 30, 100000, 'active')
ON CONFLICT (customer_id) DO NOTHING;

INSERT INTO bank_accounts (account_id, tenant_id, bank_name, account_number, iban, currency_code, current_balance, status)
VALUES
    ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Emirates NBD', '1234567890', 'AE070331234567890123456', 'AED', 500000, 'active')
ON CONFLICT (account_id) DO NOTHING;
