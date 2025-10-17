-- GL Entries for Reconciliation Testing
-- Some match exactly, some have variations to test fuzzy/AI matching

-- 1. EXACT MATCH: Rent payment (same date, amount, description)
INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, description, total_debit, total_credit, status, created_at)
VALUES ('00000000-0000-0000-0002-000000000001', '00000000-0000-0000-0000-000000000001', 'JE-2025-101', '2025-01-15', 'Office rent payment - Dubai Properties', 5000.00, 5000.00, 'posted', NOW());

INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
VALUES
  ('00000000-0000-0000-0003-000000000001', '00000000-0000-0000-0002-000000000001', '00000000-0000-0000-0000-000000000001', 1,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '5300' LIMIT 1), 5000.00, 0, 'Rent Expense'),
  ('00000000-0000-0000-0003-000000000002', '00000000-0000-0000-0002-000000000001', '00000000-0000-0000-0000-000000000001', 2,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '1000' LIMIT 1), 0, 5000.00, 'Cash Payment');

-- 2. FUZZY MATCH: DEWA bill (slightly different description)
INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, description, total_debit, total_credit, status, created_at)
VALUES ('00000000-0000-0000-0002-000000000002', '00000000-0000-0000-0000-000000000001', 'JE-2025-102', '2025-01-18', 'Electricity bill payment to DEWA', 1200.00, 1200.00, 'posted', NOW());

INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
VALUES
  ('00000000-0000-0000-0003-000000000003', '00000000-0000-0000-0002-000000000002', '00000000-0000-0000-0000-000000000001', 1,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '5400' LIMIT 1), 1200.00, 0, 'Utilities'),
  ('00000000-0000-0000-0003-000000000004', '00000000-0000-0000-0002-000000000002', '00000000-0000-0000-0000-000000000001', 2,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '1000' LIMIT 1), 0, 1200.00, 'Cash Payment');

-- 3. DATE VARIATION: Salary (posted a day later in GL)
INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, description, total_debit, total_credit, status, created_at)
VALUES ('00000000-0000-0000-0002-000000000003', '00000000-0000-0000-0000-000000000001', 'JE-2025-103', '2025-01-21', 'Monthly salary payment to employees', 25000.00, 25000.00, 'posted', NOW());

INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
VALUES
  ('00000000-0000-0000-0003-000000000005', '00000000-0000-0000-0002-000000000003', '00000000-0000-0000-0000-000000000001', 1,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '5200' LIMIT 1), 25000.00, 0, 'Salaries'),
  ('00000000-0000-0000-0003-000000000006', '00000000-0000-0000-0002-000000000003', '00000000-0000-0000-0000-000000000001', 2,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '1000' LIMIT 1), 0, 25000.00, 'Cash Payment');

-- 4. AI MATCH NEEDED: Google Workspace (abbreviated differently)
INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, description, total_debit, total_credit, status, created_at)
VALUES ('00000000-0000-0000-0002-000000000004', '00000000-0000-0000-0000-000000000001', 'JE-2025-104', '2025-01-22', 'G Suite annual subscription', 2400.00, 2400.00, 'posted', NOW());

INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
VALUES
  ('00000000-0000-0000-0003-000000000007', '00000000-0000-0000-0002-000000000004', '00000000-0000-0000-0000-000000000001', 1,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '5900' LIMIT 1), 2400.00, 0, 'IT & Software'),
  ('00000000-0000-0000-0003-000000000008', '00000000-0000-0000-0002-000000000004', '00000000-0000-0000-0000-000000000001', 2,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '1000' LIMIT 1), 0, 2400.00, 'Credit Card Payment');

-- 5. REVENUE: Client payment (credit entry)
INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, description, total_debit, total_credit, status, created_at)
VALUES ('00000000-0000-0000-0002-000000000005', '00000000-0000-0000-0000-000000000001', 'JE-2025-105', '2025-01-25', 'Payment received from Acme Corporation', 15000.00, 15000.00, 'posted', NOW());

INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
VALUES
  ('00000000-0000-0000-0003-000000000009', '00000000-0000-0000-0002-000000000005', '00000000-0000-0000-0000-000000000001', 1,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '1000' LIMIT 1), 15000.00, 0, 'Cash Received'),
  ('00000000-0000-0000-0003-000000000010', '00000000-0000-0000-0002-000000000005', '00000000-0000-0000-0000-000000000001', 2,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '4000' LIMIT 1), 0, 15000.00, 'Revenue');

-- 6. MARKETING: Facebook Ads (different vendor name format)
INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, description, total_debit, total_credit, status, created_at)
VALUES ('00000000-0000-0000-0002-000000000006', '00000000-0000-0000-0000-000000000001', 'JE-2025-106', '2025-01-28', 'Meta advertising campaign spend', 5000.00, 5000.00, 'posted', NOW());

INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
VALUES
  ('00000000-0000-0000-0003-000000000011', '00000000-0000-0000-0002-000000000006', '00000000-0000-0000-0000-000000000001', 1,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '5700' LIMIT 1), 5000.00, 0, 'Marketing'),
  ('00000000-0000-0000-0003-000000000012', '00000000-0000-0000-0002-000000000006', '00000000-0000-0000-0000-000000000001', 2,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '1000' LIMIT 1), 0, 5000.00, 'Credit Card');

-- 7. NO MATCH: Office Depot (not recorded in GL yet - should show as unmatched)
-- This is intentionally missing to test unmatched bank transactions

-- 8. Bank Charges (exact match)
INSERT INTO journal_entries (entry_id, tenant_id, entry_number, entry_date, description, total_debit, total_credit, status, created_at)
VALUES ('00000000-0000-0000-0002-000000000007', '00000000-0000-0000-0000-000000000001', 'JE-2025-107', '2025-01-31', 'Bank charges for January', 250.00, 250.00, 'posted', NOW());

INSERT INTO journal_entry_lines (line_id, entry_id, tenant_id, line_number, account_id, debit_amount, credit_amount, description)
VALUES
  ('00000000-0000-0000-0003-000000000013', '00000000-0000-0000-0002-000000000007', '00000000-0000-0000-0000-000000000001', 1,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '6200' LIMIT 1), 250.00, 0, 'Bank Charges'),
  ('00000000-0000-0000-0003-000000000014', '00000000-0000-0000-0002-000000000007', '00000000-0000-0000-0000-000000000001', 2,
   (SELECT account_id FROM chart_of_accounts WHERE account_code = '1000' LIMIT 1), 0, 250.00, 'Cash');

-- Refresh trial balance materialized view
REFRESH MATERIALIZED VIEW CONCURRENT trial_balance;
