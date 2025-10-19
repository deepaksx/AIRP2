import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import * as ExcelJS from 'exceljs';

@Injectable()
export class ReportingService {
  private readonly logger = new Logger(ReportingService.name);

  constructor(
    @InjectDataSource()
    private dataSource: DataSource,
  ) {}

  async getTrialBalance(params: any): Promise<any> {
    this.logger.log(`Fetching trial balance for tenant: ${params.tenant_id}`);

    let query: string;
    let queryParams: any[];

    if (params.period_end_date) {
      // Query for specific period
      query = `
        SELECT account_code, account_name, account_type,
               debit_balance, credit_balance, net_balance
        FROM trial_balance
        WHERE tenant_id = $1
          AND period_end_date = $2
        ORDER BY account_code
      `;
      queryParams = [params.tenant_id, params.period_end_date];
    } else {
      // Query for all accounts (includes zero-balance accounts)
      query = `
        SELECT account_code, account_name, account_type,
               debit_balance, credit_balance, net_balance, period_end_date
        FROM trial_balance
        WHERE tenant_id = $1
        ORDER BY account_code
      `;
      queryParams = [params.tenant_id];
    }

    const results = await this.dataSource.query(query, queryParams);

    // Map to expected format with total_debit/total_credit for backwards compatibility
    const accounts = results.map(r => ({
      account_code: r.account_code,
      account_name: r.account_name,
      account_type: r.account_type,
      total_debit: r.debit_balance,
      total_credit: r.credit_balance,
      net_balance: r.net_balance,
    }));

    return {
      tenant_id: params.tenant_id,
      period_end_date: results.length > 0 ? results[0].period_end_date : null,
      accounts: accounts,
      total_debits: accounts.reduce((sum, r) => sum + parseFloat(r.total_debit || 0), 0),
      total_credits: accounts.reduce((sum, r) => sum + parseFloat(r.total_credit || 0), 0),
      is_balanced: Math.abs(
        accounts.reduce((sum, r) => sum + parseFloat(r.total_debit || 0), 0) -
        accounts.reduce((sum, r) => sum + parseFloat(r.total_credit || 0), 0)
      ) < 0.01,
    };
  }

  async getVendorLedger(params: any): Promise<any> {
    this.logger.log(`Fetching vendor ledger for vendor: ${params.vendor_id}`);

    // Query journal entry lines with vendor dimension tracking
    const query = `
      SELECT
        je.entry_id,
        je.entry_number,
        je.entry_date,
        je.posting_date,
        je.description as entry_description,
        jel.line_number,
        jel.debit_amount,
        jel.credit_amount,
        jel.description as line_description,
        jel.metadata->>'invoiceNumber' as invoice_number,
        jel.metadata->>'dueDate' as due_date,
        jel.metadata->>'paymentTerms' as payment_terms,
        jel.metadata->>'vendor_name' as vendor_name,
        coa.account_code,
        coa.account_name,
        je.created_at
      FROM journal_entry_lines jel
      JOIN journal_entries je ON jel.entry_id = je.entry_id
      JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
      WHERE jel.tenant_id = $1
        AND jel.dimension_1 = $2
        AND coa.account_code = '2100'
      ORDER BY je.entry_date ASC, je.posting_date ASC, jel.line_number ASC
    `;

    const results = await this.dataSource.query(query, [params.tenant_id, params.vendor_id]);

    // Calculate running balance
    // AP account: credit increases balance, debit decreases balance
    let runningBalance = 0;
    const transactions = results.map(r => {
      const debit = parseFloat(r.debit_amount || 0);
      const credit = parseFloat(r.credit_amount || 0);
      const amount = credit - debit; // Net change to AP balance
      runningBalance += amount;

      return {
        entry_id: r.entry_id,
        entry_number: r.entry_number,
        entry_date: r.entry_date,
        posting_date: r.posting_date,
        description: r.line_description || r.entry_description,
        invoice_number: r.invoice_number,
        due_date: r.due_date,
        payment_terms: r.payment_terms,
        debit_amount: debit,
        credit_amount: credit,
        amount: amount,
        running_balance: runningBalance,
        account_code: r.account_code,
        account_name: r.account_name,
      };
    });

    return {
      tenant_id: params.tenant_id,
      vendor_id: params.vendor_id,
      vendor_name: results.length > 0 && results[0].vendor_name ? results[0].vendor_name : params.vendor_id,
      generated_at: new Date().toISOString(),
      transactions: transactions,
      summary: {
        total_debits: transactions.reduce((sum, t) => sum + t.debit_amount, 0),
        total_credits: transactions.reduce((sum, t) => sum + t.credit_amount, 0),
        current_balance: runningBalance,
        transaction_count: results.length,
      },
    };
  }

  async getVendorTransactions(params: any): Promise<any> {
    this.logger.log(`Fetching vendor transaction history for vendor: ${params.vendor_id || 'all vendors'}`);

    // Build dynamic query based on parameters
    let whereClause = 'WHERE jel.tenant_id = $1 AND jel.dimension_1 IS NOT NULL';
    const queryParams: any[] = [params.tenant_id];
    let paramIndex = 2;

    // Filter by specific vendor if provided
    if (params.vendor_id) {
      whereClause += ` AND jel.dimension_1 = $${paramIndex}`;
      queryParams.push(params.vendor_id);
      paramIndex++;
    }

    // Filter by date range if provided
    if (params.start_date) {
      whereClause += ` AND je.entry_date >= $${paramIndex}::date`;
      queryParams.push(params.start_date);
      paramIndex++;
    }

    if (params.end_date) {
      whereClause += ` AND je.entry_date <= $${paramIndex}::date`;
      queryParams.push(params.end_date);
      paramIndex++;
    }

    // Filter by account if provided
    if (params.account_code) {
      whereClause += ` AND coa.account_code = $${paramIndex}`;
      queryParams.push(params.account_code);
      paramIndex++;
    }

    // Add filter for valid UUID format to prevent cast errors
    // ALWAYS filter for valid UUIDs before attempting the cast
    const extendedWhereClause = whereClause + ` AND jel.dimension_1 ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'`;

    const query = `
      WITH filtered_lines AS (
        SELECT
          jel.*,
          jel.dimension_1::uuid as vendor_id_uuid
        FROM journal_entry_lines jel
        ${extendedWhereClause}
      )
      SELECT
        fl.line_id,
        je.entry_id,
        je.entry_number,
        je.entry_date,
        je.posting_date,
        je.entry_type,
        je.source_type,
        je.description as entry_description,
        je.status,
        fl.line_number,
        fl.debit_amount,
        fl.credit_amount,
        fl.description as line_description,
        fl.vendor_id_uuid as vendor_id,
        fl.metadata->>'invoiceNumber' as invoice_number,
        fl.metadata->>'dueDate' as due_date,
        fl.metadata->>'paymentTerms' as payment_terms,
        coa.account_id,
        coa.account_code,
        coa.account_name,
        coa.account_type,
        coa.account_subtype,
        v.vendor_code,
        v.vendor_name,
        v.contact_email as vendor_email,
        v.payment_terms as vendor_payment_terms,
        je.created_at
      FROM filtered_lines fl
      JOIN journal_entries je ON fl.entry_id = je.entry_id
      JOIN chart_of_accounts coa ON fl.account_id = coa.account_id
      LEFT JOIN vendors v ON fl.vendor_id_uuid = v.vendor_id
      ORDER BY je.entry_date DESC, je.posting_date DESC, fl.line_number ASC
      ${params.limit ? `LIMIT ${parseInt(params.limit)}` : ''}
    `;

    const results = await this.dataSource.query(query, queryParams);

    // Group transactions by vendor if showing all vendors
    const vendorMap = new Map();
    let totalDebits = 0;
    let totalCredits = 0;

    results.forEach(r => {
      const debit = parseFloat(r.debit_amount || 0);
      const credit = parseFloat(r.credit_amount || 0);
      totalDebits += debit;
      totalCredits += credit;

      const transaction = {
        line_id: r.line_id,
        entry_id: r.entry_id,
        entry_number: r.entry_number,
        entry_date: r.entry_date,
        posting_date: r.posting_date,
        entry_type: r.entry_type,
        source_type: r.source_type,
        description: r.line_description || r.entry_description,
        entry_description: r.entry_description,
        line_number: r.line_number,
        debit_amount: debit,
        credit_amount: credit,
        net_amount: credit - debit,
        account_id: r.account_id,
        account_code: r.account_code,
        account_name: r.account_name,
        account_type: r.account_type,
        account_subtype: r.account_subtype,
        invoice_number: r.invoice_number,
        due_date: r.due_date,
        payment_terms: r.payment_terms,
        vendor_id: r.vendor_id,
        vendor_code: r.vendor_code,
        vendor_name: r.vendor_name,
        vendor_email: r.vendor_email,
        created_at: r.created_at,
      };

      // Group by vendor
      if (!vendorMap.has(r.vendor_id)) {
        vendorMap.set(r.vendor_id, {
          vendor_id: r.vendor_id,
          vendor_code: r.vendor_code,
          vendor_name: r.vendor_name,
          vendor_email: r.vendor_email,
          payment_terms: r.vendor_payment_terms,
          transactions: [],
          total_debits: 0,
          total_credits: 0,
        });
      }

      const vendor = vendorMap.get(r.vendor_id);
      vendor.transactions.push(transaction);
      vendor.total_debits += debit;
      vendor.total_credits += credit;
    });

    const vendors = Array.from(vendorMap.values());

    return {
      tenant_id: params.tenant_id,
      vendor_id: params.vendor_id || null,
      start_date: params.start_date || null,
      end_date: params.end_date || null,
      account_code: params.account_code || null,
      generated_at: new Date().toISOString(),
      vendors: vendors,
      summary: {
        total_vendors: vendors.length,
        total_transactions: results.length,
        total_debits: totalDebits,
        total_credits: totalCredits,
        net_amount: totalCredits - totalDebits,
      },
    };
  }

  async getCustomerLedger(params: any): Promise<any> {
    this.logger.log(`Fetching customer ledger for customer: ${params.customer_id}`);

    const query = `
      SELECT
        ai.invoice_id,
        ai.invoice_number,
        ai.invoice_date,
        ai.due_date,
        ai.subtotal,
        ai.tax_amount,
        ai.total_amount,
        ai.amount_paid,
        ai.amount_outstanding,
        ai.status,
        ai.payment_status,
        c.customer_name,
        c.customer_code,
        ai.created_at
      FROM ar_invoices ai
      JOIN customers c ON ai.customer_id = c.customer_id
      WHERE ai.tenant_id = $1
        AND ai.customer_id = $2
      ORDER BY ai.invoice_date ASC, ai.created_at ASC
    `;

    const results = await this.dataSource.query(query, [params.tenant_id, params.customer_id]);

    // Calculate running balance
    let runningBalance = 0;
    const invoicesWithBalance = results.map(r => {
      runningBalance += parseFloat(r.amount_outstanding || 0);
      return {
        invoice_id: r.invoice_id,
        invoice_number: r.invoice_number,
        invoice_date: r.invoice_date,
        due_date: r.due_date,
        subtotal: parseFloat(r.subtotal),
        tax_amount: parseFloat(r.tax_amount),
        total_amount: parseFloat(r.total_amount),
        amount_paid: parseFloat(r.amount_paid),
        amount_outstanding: parseFloat(r.amount_outstanding),
        running_balance: runningBalance,
        status: r.status,
        payment_status: r.payment_status,
      };
    });

    return {
      tenant_id: params.tenant_id,
      customer_id: params.customer_id,
      customer_name: results.length > 0 ? results[0].customer_name : null,
      customer_code: results.length > 0 ? results[0].customer_code : null,
      generated_at: new Date().toISOString(),
      invoices: invoicesWithBalance,
      total_outstanding: runningBalance,
      invoice_count: results.length,
    };
  }

  async getAccountBalances(params: any): Promise<any> {
    this.logger.log(`Fetching account balances for tenant: ${params.tenant_id}`);

    const query = `
      SELECT
        gb.account_id,
        coa.account_code,
        coa.account_name,
        coa.account_type,
        coa.account_subtype,
        gb.fiscal_year,
        gb.fiscal_period,
        gb.currency,
        SUM(gb.debit_amount) as total_debit,
        SUM(gb.credit_amount) as total_credit,
        SUM(gb.balance) as net_balance
      FROM gl_balances gb
      JOIN chart_of_accounts coa ON gb.account_id = coa.account_id
      WHERE gb.tenant_id = $1
      GROUP BY
        gb.account_id,
        coa.account_code,
        coa.account_name,
        coa.account_type,
        coa.account_subtype,
        gb.fiscal_year,
        gb.fiscal_period,
        gb.currency
      ORDER BY coa.account_code, gb.fiscal_year, gb.fiscal_period
    `;

    const results = await this.dataSource.query(query, [params.tenant_id]);

    // Group by account
    const accountsMap = new Map();
    results.forEach(r => {
      const key = r.account_code;
      if (!accountsMap.has(key)) {
        accountsMap.set(key, {
          account_id: r.account_id,
          account_code: r.account_code,
          account_name: r.account_name,
          account_type: r.account_type,
          account_subtype: r.account_subtype,
          currency: r.currency,
          periods: [],
          total_debit: 0,
          total_credit: 0,
          net_balance: 0,
        });
      }

      const account = accountsMap.get(key);
      account.periods.push({
        fiscal_year: r.fiscal_year,
        fiscal_period: r.fiscal_period,
        debit_amount: parseFloat(r.total_debit || 0),
        credit_amount: parseFloat(r.total_credit || 0),
        balance: parseFloat(r.net_balance || 0),
      });
      account.total_debit += parseFloat(r.total_debit || 0);
      account.total_credit += parseFloat(r.total_credit || 0);
      account.net_balance += parseFloat(r.net_balance || 0);
    });

    const accounts = Array.from(accountsMap.values());

    return {
      tenant_id: params.tenant_id,
      generated_at: new Date().toISOString(),
      accounts: accounts,
      summary: {
        total_accounts: accounts.length,
        total_debit: accounts.reduce((sum, a) => sum + a.total_debit, 0),
        total_credit: accounts.reduce((sum, a) => sum + a.total_credit, 0),
      },
    };
  }

  async getIncomeStatement(params: any): Promise<any> {
    this.logger.log(`Generating Income Statement for tenant: ${params.tenant_id}`);

    const query = `
      SELECT
        coa.account_id,
        coa.account_code,
        coa.account_name,
        coa.account_type,
        coa.account_subtype,
        SUM(gb.debit_amount) as total_debit,
        SUM(gb.credit_amount) as total_credit,
        SUM(gb.balance) as net_balance
      FROM gl_balances gb
      JOIN chart_of_accounts coa ON gb.account_id = coa.account_id
      WHERE gb.tenant_id = $1
        AND LOWER(coa.account_type) IN ('revenue', 'expense')
        ${params.start_date ? 'AND gb.fiscal_year >= EXTRACT(YEAR FROM $2::date)' : ''}
        ${params.end_date ? 'AND gb.fiscal_year <= EXTRACT(YEAR FROM $3::date)' : ''}
      GROUP BY
        coa.account_id,
        coa.account_code,
        coa.account_name,
        coa.account_type,
        coa.account_subtype
      ORDER BY coa.account_type DESC, coa.account_code
    `;

    const queryParams: any[] = [params.tenant_id];
    if (params.start_date) queryParams.push(params.start_date);
    if (params.end_date) queryParams.push(params.end_date);

    const results = await this.dataSource.query(query, queryParams);

    this.logger.log(`Income statement query returned ${results.length} rows`);
    if (results.length > 0) {
      this.logger.log(`First row: ${JSON.stringify(results[0])}`);
    }

    // Separate revenue and expenses
    const revenue: any[] = [];
    const expenses: any[] = [];
    let totalRevenue = 0;
    let totalExpenses = 0;

    results.forEach(r => {
      const debit = parseFloat(r.total_debit || 0);
      const credit = parseFloat(r.total_credit || 0);

      // Calculate balance as DR - CR (universal accounting convention)
      // Revenue will be negative (credit balance), Expense will be positive (debit balance)
      const balance = debit - credit;

      const accountData = {
        account_id: r.account_id,
        account_code: r.account_code,
        account_name: r.account_name,
        account_subtype: r.account_subtype,
        debit_amount: debit,
        credit_amount: credit,
        // Use signed DR-CR value (not absolute)
        // Revenue = negative (credit), Expense = positive (debit)
        total_amount: balance,
      };

      if (r.account_type.toLowerCase() === 'revenue') {
        revenue.push(accountData);
        totalRevenue += balance; // Sum signed values (will be negative)
      } else {
        expenses.push(accountData);
        totalExpenses += balance; // Sum signed values (will be positive)
      }
    });

    // Net Income calculation with DR-CR signed values:
    // totalRevenue = -3,268,007.40 (negative = credit balance)
    // totalExpenses = +1,538,245.10 (positive = debit balance)
    //
    // Traditional Net Income = Revenue - Expenses = 3,268,007.40 - 1,538,245.10 = 1,729,762.30
    // With signed values: -totalRevenue - totalExpenses = -(-3,268,007.40) - 1,538,245.10 = 1,729,762.30
    //
    // Profit (positive) = Revenue > Expenses
    // Loss (negative) = Revenue < Expenses
    const netIncomeTraditional = -totalRevenue - totalExpenses; // Traditional format (profit = positive)

    // DR-CR signed value for Net Income (for accounting equation)
    // Profit is a credit to Retained Earnings, so it's negative in DR-CR
    const netIncomeDRCR = -netIncomeTraditional; // Negate to get DR-CR (profit = negative)

    return {
      tenant_id: params.tenant_id,
      start_date: params.start_date || null,
      end_date: params.end_date || null,
      generated_at: new Date().toISOString(),
      revenue: revenue,
      expenses: expenses,
      summary: {
        total_revenue: totalRevenue, // Negative for credit balance
        total_expenses: totalExpenses, // Positive for debit balance
        net_income: netIncomeDRCR, // Signed DR-CR value (negative for profit, for accounting equation)
        net_income_display: netIncomeTraditional, // Traditional display (positive for profit)
        profit_margin: totalRevenue < 0 ? (netIncomeTraditional / Math.abs(totalRevenue)) * 100 : 0,
      },
    };
  }

  async getProfitLoss(params: any): Promise<any> {
    // Redirect to Income Statement (they're the same)
    return this.getIncomeStatement(params);
  }

  async getBalanceSheet(params: any): Promise<any> {
    this.logger.log(`Generating balance sheet for tenant: ${params.tenant_id}`);

    const query = `
      SELECT
        coa.account_id,
        coa.account_code,
        coa.account_name,
        coa.account_type,
        coa.account_subtype,
        coa.normal_balance,
        SUM(gb.debit_amount) as total_debit,
        SUM(gb.credit_amount) as total_credit,
        SUM(gb.balance) as net_balance
      FROM gl_balances gb
      JOIN chart_of_accounts coa ON gb.account_id = coa.account_id
      WHERE gb.tenant_id = $1
        AND LOWER(coa.account_type) IN ('asset', 'liability', 'equity')
        ${params.as_of_date ? `AND MAKE_DATE(gb.fiscal_year, gb.fiscal_period, 1) <= $2::date` : ''}
      GROUP BY
        coa.account_id,
        coa.account_code,
        coa.account_name,
        coa.account_type,
        coa.account_subtype,
        coa.normal_balance
      ORDER BY coa.account_type, coa.account_code
    `;

    const queryParams: any[] = [params.tenant_id];
    if (params.as_of_date) queryParams.push(params.as_of_date);

    const results = await this.dataSource.query(query, queryParams);

    // Query for revenue and expense accounts to calculate Retained Earnings
    const incomeQuery = `
      SELECT
        coa.account_type,
        coa.normal_balance,
        SUM(gb.debit_amount) as total_debit,
        SUM(gb.credit_amount) as total_credit
      FROM gl_balances gb
      JOIN chart_of_accounts coa ON gb.account_id = coa.account_id
      WHERE gb.tenant_id = $1
        AND LOWER(coa.account_type) IN ('revenue', 'expense')
        ${params.as_of_date ? `AND MAKE_DATE(gb.fiscal_year, gb.fiscal_period, 1) <= $2::date` : ''}
      GROUP BY coa.account_type, coa.normal_balance
    `;

    const incomeResults = await this.dataSource.query(incomeQuery, queryParams);

    // Calculate Retained Earnings (Revenue - Expenses)
    let retainedEarnings = 0;
    let revenueTotal = 0;
    let expenseTotal = 0;

    incomeResults.forEach(r => {
      const debit = parseFloat(r.total_debit || 0);
      const credit = parseFloat(r.total_credit || 0);
      const accountType = (r.account_type || '').toLowerCase();

      if (accountType === 'revenue') {
        revenueTotal = credit - debit; // Revenue normal balance is CREDIT
      } else if (accountType === 'expense') {
        expenseTotal = debit - credit; // Expense normal balance is DEBIT
      }
    });

    retainedEarnings = revenueTotal - expenseTotal;

    // Separate assets, liabilities, and equity
    const assets: any[] = [];
    const liabilities: any[] = [];
    const equity: any[] = [];
    let totalAssets = 0;
    let totalLiabilities = 0;
    let totalEquity = 0;

    results.forEach(r => {
      const debit = parseFloat(r.total_debit || 0);
      const credit = parseFloat(r.total_credit || 0);

      // Calculate balance as DR - CR (universal accounting convention)
      // Positive = Debit balance, Negative = Credit balance
      const balance = debit - credit;

      const accountData = {
        account_id: r.account_id,
        account_code: r.account_code,
        account_name: r.account_name,
        account_subtype: r.account_subtype,
        normal_balance: r.normal_balance,
        debit_amount: debit,
        credit_amount: credit,
        balance: balance, // Signed DR-CR value (not absolute)
      };

      const accountType = r.account_type.toLowerCase();
      if (accountType === 'asset') {
        assets.push(accountData);
        totalAssets += balance; // Sum signed values
      } else if (accountType === 'liability') {
        liabilities.push(accountData);
        totalLiabilities += balance; // Sum signed values
      } else if (accountType === 'equity') {
        equity.push(accountData);
        totalEquity += balance; // Sum signed values
      }
    });

    // Add Retained Earnings to equity
    if (retainedEarnings !== 0) {
      // Retained Earnings = Revenue - Expense
      // Revenue has credit balance (negative DR-CR), Expense has debit balance (positive DR-CR)
      // So: Retained Earnings = -revenueTotal - expenseTotal (will be negative for profit)
      const retainedEarningsDRCR = -retainedEarnings; // Negate because profit is credit balance

      equity.push({
        account_id: 'RETAINED-EARNINGS',
        account_code: '3100',
        account_name: 'Retained Earnings (Current Period)',
        account_subtype: null,
        normal_balance: 'CREDIT',
        debit_amount: retainedEarnings < 0 ? Math.abs(retainedEarnings) : 0, // Loss = Debit
        credit_amount: retainedEarnings > 0 ? retainedEarnings : 0, // Profit = Credit
        balance: retainedEarningsDRCR, // Signed DR-CR value (negative for profit)
        is_calculated: true, // Flag to indicate this is a calculated account
        revenue_total: revenueTotal,
        expense_total: expenseTotal,
      });
      totalEquity += retainedEarningsDRCR; // Sum signed values
    }

    const isBalanced = Math.abs(totalAssets + totalLiabilities + totalEquity) < 0.01; // Should sum to zero with signed values

    return {
      tenant_id: params.tenant_id,
      as_of_date: params.as_of_date || new Date().toISOString().split('T')[0],
      generated_at: new Date().toISOString(),
      assets: assets,
      liabilities: liabilities,
      equity: equity,
      summary: {
        total_assets: totalAssets,
        total_liabilities: totalLiabilities,
        total_equity: totalEquity,
        retained_earnings: retainedEarnings,
        revenue_total: revenueTotal,
        expense_total: expenseTotal,
        is_balanced: isBalanced,
        variance: totalAssets - (totalLiabilities + totalEquity),
      },
    };
  }

  async getCashFlow(params: any): Promise<any> {
    this.logger.log(`Generating cash flow statement for tenant: ${params.tenant_id}`);

    const query = `
      SELECT
        bt.transaction_id,
        bt.transaction_date,
        bt.value_date,
        bt.description,
        bt.reference,
        bt.debit_amount,
        bt.credit_amount,
        bt.balance,
        bt.currency,
        ba.account_name as bank_account_name,
        ba.account_code as bank_account_code
      FROM bank_transactions bt
      JOIN bank_accounts ba ON bt.bank_account_id = ba.bank_account_id
      WHERE bt.tenant_id = $1
        ${params.start_date ? 'AND bt.transaction_date >= $2::date' : ''}
        ${params.end_date ? 'AND bt.transaction_date <= $3::date' : ''}
      ORDER BY bt.transaction_date ASC, bt.value_date ASC
    `;

    const queryParams: any[] = [params.tenant_id];
    if (params.start_date) queryParams.push(params.start_date);
    if (params.end_date) queryParams.push(params.end_date);

    const results = await this.dataSource.query(query, queryParams);

    // Categorize transactions
    const operating: any[] = [];
    const investing: any[] = [];
    const financing: any[] = [];
    let totalInflows = 0;
    let totalOutflows = 0;

    results.forEach(r => {
      const transaction = {
        transaction_id: r.transaction_id,
        transaction_date: r.transaction_date,
        value_date: r.value_date,
        description: r.description,
        reference: r.reference,
        debit_amount: parseFloat(r.debit_amount || 0),
        credit_amount: parseFloat(r.credit_amount || 0),
        net_amount: parseFloat(r.credit_amount || 0) - parseFloat(r.debit_amount || 0),
        balance: parseFloat(r.balance || 0),
        bank_account_name: r.bank_account_name,
        bank_account_code: r.bank_account_code,
      };

      totalInflows += transaction.credit_amount;
      totalOutflows += transaction.debit_amount;

      // Simple categorization based on description keywords
      // In a real system, this would use GL account mappings or AI categorization
      const desc = (r.description || '').toLowerCase();
      if (desc.includes('invest') || desc.includes('asset purchase') || desc.includes('equipment')) {
        investing.push(transaction);
      } else if (desc.includes('loan') || desc.includes('dividend') || desc.includes('capital')) {
        financing.push(transaction);
      } else {
        operating.push(transaction);
      }
    });

    const netCashFlow = totalInflows - totalOutflows;
    const openingBalance = results.length > 0 ? parseFloat(results[0].balance || 0) - (parseFloat(results[0].credit_amount || 0) - parseFloat(results[0].debit_amount || 0)) : 0;
    const closingBalance = results.length > 0 ? parseFloat(results[results.length - 1].balance || 0) : 0;

    return {
      tenant_id: params.tenant_id,
      start_date: params.start_date || null,
      end_date: params.end_date || null,
      generated_at: new Date().toISOString(),
      operating_activities: operating,
      investing_activities: investing,
      financing_activities: financing,
      summary: {
        total_inflows: totalInflows,
        total_outflows: totalOutflows,
        net_cash_flow: netCashFlow,
        opening_balance: openingBalance,
        closing_balance: closingBalance,
        operating_cash_flow: operating.reduce((sum, t) => sum + t.net_amount, 0),
        investing_cash_flow: investing.reduce((sum, t) => sum + t.net_amount, 0),
        financing_cash_flow: financing.reduce((sum, t) => sum + t.net_amount, 0),
      },
    };
  }

  async getAPAging(params: any): Promise<any> {
    this.logger.log(`Fetching AP aging report for tenant: ${params.tenant_id}`);

    const asOfDate = params.as_of_date || new Date().toISOString().split('T')[0];

    // Query all unpaid AP invoices with vendor information
    const query = `
      SELECT
        ai.invoice_id,
        ai.vendor_id,
        v.vendor_code,
        v.vendor_name,
        v.payment_terms,
        ai.invoice_number,
        ai.invoice_date,
        ai.due_date,
        ai.total_amount,
        ai.amount_outstanding,
        ai.currency,
        ($1::date - ai.due_date::date) as days_outstanding
      FROM ap_invoices ai
      JOIN vendors v ON ai.vendor_id = v.vendor_id
      WHERE ai.tenant_id = $2
        AND ai.payment_status = 'unpaid'
        AND ai.amount_outstanding > 0
      ORDER BY v.vendor_name, ($1::date - ai.due_date::date) DESC
    `;

    const results = await this.dataSource.query(query, [asOfDate, params.tenant_id]);

    // Calculate aging buckets and group by vendor
    const vendorMap = new Map();
    let totalCurrent = 0;
    let total1to30 = 0;
    let total31to60 = 0;
    let total61to90 = 0;
    let total90Plus = 0;

    results.forEach(r => {
      const daysOutstanding = parseInt(r.days_outstanding || 0);
      const outstanding = parseFloat(r.amount_outstanding || 0);

      // Determine aging bucket
      let agingBucket = 'current';
      let bucketAmount = {
        current: 0,
        days_1_30: 0,
        days_31_60: 0,
        days_61_90: 0,
        days_90_plus: 0,
      };

      if (daysOutstanding < 0) {
        agingBucket = 'current';
        bucketAmount.current = outstanding;
        totalCurrent += outstanding;
      } else if (daysOutstanding <= 30) {
        agingBucket = '1-30 days';
        bucketAmount.days_1_30 = outstanding;
        total1to30 += outstanding;
      } else if (daysOutstanding <= 60) {
        agingBucket = '31-60 days';
        bucketAmount.days_31_60 = outstanding;
        total31to60 += outstanding;
      } else if (daysOutstanding <= 90) {
        agingBucket = '61-90 days';
        bucketAmount.days_61_90 = outstanding;
        total61to90 += outstanding;
      } else {
        agingBucket = '90+ days';
        bucketAmount.days_90_plus = outstanding;
        total90Plus += outstanding;
      }

      // Create invoice record
      const invoiceRecord = {
        invoice_id: r.invoice_id,
        invoice_number: r.invoice_number,
        invoice_date: r.invoice_date,
        due_date: r.due_date,
        days_outstanding: daysOutstanding,
        aging_bucket: agingBucket,
        total_amount: parseFloat(r.total_amount || 0),
        amount_outstanding: outstanding,
        currency: r.currency,
      };

      // Group by vendor
      if (!vendorMap.has(r.vendor_id)) {
        vendorMap.set(r.vendor_id, {
          vendor_id: r.vendor_id,
          vendor_code: r.vendor_code,
          vendor_name: r.vendor_name,
          payment_terms: r.payment_terms,
          invoices: [],
          total_outstanding: 0,
          current: 0,
          days_1_30: 0,
          days_31_60: 0,
          days_61_90: 0,
          days_90_plus: 0,
        });
      }

      const vendor = vendorMap.get(r.vendor_id);
      vendor.invoices.push(invoiceRecord);
      vendor.total_outstanding += outstanding;
      vendor.current += bucketAmount.current;
      vendor.days_1_30 += bucketAmount.days_1_30;
      vendor.days_31_60 += bucketAmount.days_31_60;
      vendor.days_61_90 += bucketAmount.days_61_90;
      vendor.days_90_plus += bucketAmount.days_90_plus;
    });

    const vendors = Array.from(vendorMap.values());

    return {
      tenant_id: params.tenant_id,
      as_of_date: asOfDate,
      generated_at: new Date().toISOString(),
      vendors: vendors,
      summary: {
        total_vendors: vendors.length,
        total_invoices: results.length,
        total_outstanding: vendors.reduce((sum, v) => sum + v.total_outstanding, 0),
        current: totalCurrent,
        days_1_30: total1to30,
        days_31_60: total31to60,
        days_61_90: total61to90,
        days_90_plus: total90Plus,
      },
    };
  }

  async getARAging(params: any): Promise<any> {
    this.logger.log(`Fetching AR aging report`);

    const query = `
      SELECT customer_name, invoice_number, invoice_date, due_date,
             outstanding_amount, days_outstanding, aging_bucket
      FROM ar_aging
      WHERE tenant_id = $1
      ORDER BY days_outstanding DESC
    `;

    const results = await this.dataSource.query(query, [params.tenant_id]);

    return {
      tenant_id: params.tenant_id,
      generated_at: new Date().toISOString(),
      invoices: results,
      total_outstanding: results.reduce((sum, r) => sum + parseFloat(r.outstanding_amount || 0), 0),
    };
  }

  async exportToExcel(params: any): Promise<any> {
    this.logger.log(`Exporting report to Excel: ${params.report_type}`);

    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Report');

    // Add headers
    worksheet.columns = [
      { header: 'Account Code', key: 'account_code', width: 15 },
      { header: 'Account Name', key: 'account_name', width: 30 },
      { header: 'Debit', key: 'debit', width: 15 },
      { header: 'Credit', key: 'credit', width: 15 },
    ];

    // In production, this would fetch actual data and populate the worksheet
    worksheet.addRow({
      account_code: '1000',
      account_name: 'Cash',
      debit: 10000,
      credit: 0,
    });

    const buffer = await workbook.xlsx.writeBuffer();
    return buffer;
  }

  async executeQuery(query: string, params: any[] = []): Promise<any> {
    this.logger.log(`Executing custom query with ${params.length} parameters`);
    try {
      const results = await this.dataSource.query(query, params);
      return results;
    } catch (error) {
      this.logger.error(`Query execution failed: ${error.message}`);
      throw error;
    }
  }
}
