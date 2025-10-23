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
        (ai.metadata->>'subtotal')::numeric as subtotal,
        (ai.metadata->>'tax_amount')::numeric as tax_amount,
        ai.total_amount,
        (ai.metadata->>'amount_paid')::numeric as amount_paid,
        ai.amount_outstanding,
        'posted' as status,
        ai.payment_status,
        c.customer_name,
        c.customer_code,
        je.created_at
      FROM vw_ar_invoices ai
      JOIN customers c ON ai.customer_id = c.customer_id
      JOIN journal_entry_lines jel ON ai.invoice_id = jel.line_id
      JOIN journal_entries je ON jel.entry_id = je.entry_id
      WHERE ai.tenant_id = $1
        AND ai.customer_id = $2
      ORDER BY ai.invoice_date ASC, je.created_at ASC
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

    const method = params.method || 'direct'; // 'direct' or 'indirect'
    const startDate = params.start_date || '2024-01-01';
    const endDate = params.end_date || new Date().toISOString().split('T')[0];

    if (method === 'indirect') {
      return this.getCashFlowIndirect(params.tenant_id, startDate, endDate);
    } else {
      return this.getCashFlowDirect(params.tenant_id, startDate, endDate);
    }
  }

  private async getCashFlowDirect(tenantId: string, startDate: string, endDate: string): Promise<any> {
    // Direct Method: Shows actual cash receipts and payments

    // Get cash account transactions (accounts 1010-1090 are bank accounts)
    const cashQuery = `
      SELECT
        je.entry_id,
        je.entry_number,
        je.entry_date,
        je.entry_type,
        je.description,
        coa.account_code,
        coa.account_name,
        jel.debit_amount,
        jel.credit_amount,
        jel.description as line_description,
        jel.metadata
      FROM journal_entry_lines jel
      JOIN journal_entries je ON jel.entry_id = je.entry_id
      JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
      WHERE jel.tenant_id = $1
        AND coa.account_code >= '1010' AND coa.account_code <= '1090'
        AND je.entry_date >= $2::date
        AND je.entry_date <= $3::date
        AND je.status = 'posted'
      ORDER BY je.entry_date ASC, je.entry_number ASC
    `;

    const cashTransactions = await this.dataSource.query(cashQuery, [tenantId, startDate, endDate]);

    // Categorize cash flows
    const operating = {
      receipts_from_customers: 0,
      payments_to_suppliers: 0,
      payments_to_employees: 0,
      interest_paid: 0,
      interest_received: 0,
      other_operating: 0,
      transactions: [],
    };

    const investing = {
      purchase_of_assets: 0,
      sale_of_assets: 0,
      purchase_of_investments: 0,
      sale_of_investments: 0,
      transactions: [],
    };

    const financing = {
      proceeds_from_borrowing: 0,
      repayment_of_borrowing: 0,
      capital_contributions: 0,
      dividends_paid: 0,
      transactions: [],
    };

    cashTransactions.forEach(tx => {
      const netAmount = parseFloat(tx.debit_amount || 0) - parseFloat(tx.credit_amount || 0);
      const transaction = {
        entry_number: tx.entry_number,
        entry_date: tx.entry_date,
        description: tx.description || tx.line_description,
        account_code: tx.account_code,
        account_name: tx.account_name,
        amount: netAmount,
      };

      // Categorize based on entry type and description
      const desc = (tx.description || '').toLowerCase();
      const entryType = (tx.entry_type || '').toLowerCase();

      if (entryType.includes('receipt') || desc.includes('customer') || desc.includes('ar ')) {
        operating.receipts_from_customers += netAmount;
        operating.transactions.push(transaction);
      } else if (entryType.includes('payment') && (desc.includes('vendor') || desc.includes('ap '))) {
        operating.payments_to_suppliers += netAmount;
        operating.transactions.push(transaction);
      } else if (entryType.includes('payroll') || desc.includes('salary') || desc.includes('wage')) {
        operating.payments_to_employees += netAmount;
        operating.transactions.push(transaction);
      } else if (desc.includes('interest paid')) {
        operating.interest_paid += netAmount;
        operating.transactions.push(transaction);
      } else if (desc.includes('interest received')) {
        operating.interest_received += netAmount;
        operating.transactions.push(transaction);
      } else if (desc.includes('asset') || desc.includes('equipment') || desc.includes('property')) {
        if (netAmount < 0) {
          investing.purchase_of_assets += netAmount;
        } else {
          investing.sale_of_assets += netAmount;
        }
        investing.transactions.push(transaction);
      } else if (desc.includes('invest')) {
        if (netAmount < 0) {
          investing.purchase_of_investments += netAmount;
        } else {
          investing.sale_of_investments += netAmount;
        }
        investing.transactions.push(transaction);
      } else if (desc.includes('loan') || desc.includes('borrow')) {
        if (netAmount > 0) {
          financing.proceeds_from_borrowing += netAmount;
        } else {
          financing.repayment_of_borrowing += netAmount;
        }
        financing.transactions.push(transaction);
      } else if (desc.includes('capital') || desc.includes('equity')) {
        financing.capital_contributions += netAmount;
        financing.transactions.push(transaction);
      } else if (desc.includes('dividend')) {
        financing.dividends_paid += netAmount;
        financing.transactions.push(transaction);
      } else {
        // Default to operating
        operating.other_operating += netAmount;
        operating.transactions.push(transaction);
      }
    });

    // Calculate totals
    const operatingCashFlow =
      operating.receipts_from_customers +
      operating.payments_to_suppliers +
      operating.payments_to_employees +
      operating.interest_paid +
      operating.interest_received +
      operating.other_operating;

    const investingCashFlow =
      investing.purchase_of_assets +
      investing.sale_of_assets +
      investing.purchase_of_investments +
      investing.sale_of_investments;

    const financingCashFlow =
      financing.proceeds_from_borrowing +
      financing.repayment_of_borrowing +
      financing.capital_contributions +
      financing.dividends_paid;

    const netCashFlow = operatingCashFlow + investingCashFlow + financingCashFlow;

    // Get opening and closing cash balances
    const balanceQuery = `
      SELECT
        SUM(CASE
          WHEN je.entry_date < $2::date
          THEN jel.debit_amount - jel.credit_amount
          ELSE 0
        END) as opening_balance,
        SUM(CASE
          WHEN je.entry_date <= $3::date
          THEN jel.debit_amount - jel.credit_amount
          ELSE 0
        END) as closing_balance
      FROM journal_entry_lines jel
      JOIN journal_entries je ON jel.entry_id = je.entry_id
      JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
      WHERE jel.tenant_id = $1
        AND coa.account_code >= '1010' AND coa.account_code <= '1090'
        AND je.status = 'posted'
    `;

    const balances = await this.dataSource.query(balanceQuery, [tenantId, startDate, endDate]);
    const openingBalance = parseFloat(balances[0]?.opening_balance || 0);
    const closingBalance = parseFloat(balances[0]?.closing_balance || 0);

    return {
      tenant_id: tenantId,
      method: 'direct',
      start_date: startDate,
      end_date: endDate,
      generated_at: new Date().toISOString(),
      currency: 'AED',
      operating_activities: {
        receipts_from_customers: operating.receipts_from_customers,
        payments_to_suppliers: operating.payments_to_suppliers,
        payments_to_employees: operating.payments_to_employees,
        interest_paid: operating.interest_paid,
        interest_received: operating.interest_received,
        other_operating_cash_flows: operating.other_operating,
        net_cash_from_operating: operatingCashFlow,
        transactions: operating.transactions,
      },
      investing_activities: {
        purchase_of_property_plant_equipment: investing.purchase_of_assets,
        proceeds_from_sale_of_assets: investing.sale_of_assets,
        purchase_of_investments: investing.purchase_of_investments,
        proceeds_from_sale_of_investments: investing.sale_of_investments,
        net_cash_from_investing: investingCashFlow,
        transactions: investing.transactions,
      },
      financing_activities: {
        proceeds_from_borrowings: financing.proceeds_from_borrowing,
        repayment_of_borrowings: financing.repayment_of_borrowing,
        proceeds_from_share_capital: financing.capital_contributions,
        dividends_paid: financing.dividends_paid,
        net_cash_from_financing: financingCashFlow,
        transactions: financing.transactions,
      },
      summary: {
        net_cash_from_operating: operatingCashFlow,
        net_cash_from_investing: investingCashFlow,
        net_cash_from_financing: financingCashFlow,
        net_increase_in_cash: netCashFlow,
        cash_at_beginning: openingBalance,
        cash_at_end: closingBalance,
      },
    };
  }

  private async getCashFlowIndirect(tenantId: string, startDate: string, endDate: string): Promise<any> {
    // Indirect Method: Starts with net income and adjusts for non-cash items

    // Get net income from Income Statement
    const incomeQuery = `
      SELECT
        COALESCE(SUM(CASE WHEN coa.account_type = 'Revenue' THEN gb.credit_amount - gb.debit_amount ELSE 0 END), 0) as revenue,
        COALESCE(SUM(CASE WHEN coa.account_type = 'Expense' THEN gb.debit_amount - gb.credit_amount ELSE 0 END), 0) as expenses
      FROM gl_balances gb
      JOIN chart_of_accounts coa ON gb.account_id = coa.account_id
      WHERE gb.tenant_id = $1
        AND coa.account_type IN ('Revenue', 'Expense')
    `;

    const incomeResult = await this.dataSource.query(incomeQuery, [tenantId]);
    const revenue = parseFloat(incomeResult[0]?.revenue || 0);
    const expenses = parseFloat(incomeResult[0]?.expenses || 0);
    const netIncome = revenue - expenses;

    // Get changes in working capital
    const workingCapitalQuery = `
      SELECT
        coa.account_code,
        coa.account_name,
        coa.account_type,
        COALESCE(SUM(gb.debit_amount - gb.credit_amount), 0) as balance
      FROM gl_balances gb
      JOIN chart_of_accounts coa ON gb.account_id = coa.account_id
      WHERE gb.tenant_id = $1
        AND (
          (coa.account_code >= '1100' AND coa.account_code < '1200') OR -- Current assets (non-cash)
          (coa.account_code >= '1200' AND coa.account_code < '1600') OR -- Receivables
          (coa.account_code >= '2000' AND coa.account_code < '2500')    -- Current liabilities
        )
      GROUP BY coa.account_code, coa.account_name, coa.account_type
      ORDER BY coa.account_code
    `;

    const wcChanges = await this.dataSource.query(workingCapitalQuery, [tenantId]);

    let arIncrease = 0;
    let apIncrease = 0;
    let inventoryIncrease = 0;
    let otherWCChanges = 0;

    wcChanges.forEach(wc => {
      const balance = parseFloat(wc.balance || 0);
      if (wc.account_code >= '1200' && wc.account_code < '1300') {
        arIncrease += balance; // AR increase = use of cash
      } else if (wc.account_code >= '2100' && wc.account_code < '2200') {
        apIncrease += balance; // AP increase = source of cash
      } else if (wc.account_code >= '1400' && wc.account_code < '1500') {
        inventoryIncrease += balance;
      } else {
        otherWCChanges += balance;
      }
    });

    // Adjustments for non-cash items (depreciation, amortization, etc.)
    const nonCashQuery = `
      SELECT
        COALESCE(SUM(CASE
          WHEN je.description ILIKE '%depreciation%' OR je.description ILIKE '%amortization%'
          THEN jel.debit_amount
          ELSE 0
        END), 0) as depreciation_amortization
      FROM journal_entry_lines jel
      JOIN journal_entries je ON jel.entry_id = je.entry_id
      WHERE jel.tenant_id = $1
        AND je.entry_date >= $2::date
        AND je.entry_date <= $3::date
        AND je.status = 'posted'
    `;

    const nonCash = await this.dataSource.query(nonCashQuery, [tenantId, startDate, endDate]);
    const depreciation = parseFloat(nonCash[0]?.depreciation_amortization || 0);

    // Operating cash flow calculation
    const operatingCashFlow = netIncome +
      depreciation -
      arIncrease +
      apIncrease -
      inventoryIncrease +
      otherWCChanges;

    // Get investing and financing activities (same as direct method)
    const directMethod = await this.getCashFlowDirect(tenantId, startDate, endDate);

    return {
      tenant_id: tenantId,
      method: 'indirect',
      start_date: startDate,
      end_date: endDate,
      generated_at: new Date().toISOString(),
      currency: 'AED',
      operating_activities: {
        net_income: netIncome,
        adjustments_for_non_cash_items: {
          depreciation_and_amortization: depreciation,
        },
        changes_in_working_capital: {
          increase_in_accounts_receivable: -arIncrease,
          increase_in_inventory: -inventoryIncrease,
          increase_in_accounts_payable: apIncrease,
          other_working_capital_changes: otherWCChanges,
        },
        net_cash_from_operating: operatingCashFlow,
      },
      investing_activities: directMethod.investing_activities,
      financing_activities: directMethod.financing_activities,
      summary: {
        net_cash_from_operating: operatingCashFlow,
        net_cash_from_investing: directMethod.summary.net_cash_from_investing,
        net_cash_from_financing: directMethod.summary.net_cash_from_financing,
        net_increase_in_cash: operatingCashFlow + directMethod.summary.net_cash_from_investing + directMethod.summary.net_cash_from_financing,
        cash_at_beginning: directMethod.summary.cash_at_beginning,
        cash_at_end: directMethod.summary.cash_at_end,
      },
    };
  }

  async getAPAging(params: any): Promise<any> {
    this.logger.log(`Fetching AP aging report for tenant: ${params.tenant_id}`);

    const asOfDate = params.as_of_date || new Date().toISOString().split('T')[0];

    // Query materialized view for AP aging
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
        ai.days_outstanding
      FROM vw_ap_invoices ai
      JOIN vendors v ON ai.vendor_id = v.vendor_id
      WHERE ai.tenant_id = $1
        AND ai.payment_status IN ('unpaid', 'partial')
        AND ai.amount_outstanding > 0
      ORDER BY v.vendor_name, ai.days_outstanding DESC
    `;

    const results = await this.dataSource.query(query, [params.tenant_id]);

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
    this.logger.log(`Fetching AR aging report for tenant: ${params.tenant_id}`);

    const asOfDate = params.as_of_date || new Date().toISOString().split('T')[0];

    // Query materialized view for AR aging
    const query = `
      SELECT
        ai.invoice_id,
        ai.customer_id,
        c.customer_code,
        c.customer_name,
        c.payment_terms,
        ai.invoice_number,
        ai.invoice_date,
        ai.due_date,
        ai.total_amount,
        ai.amount_outstanding,
        ai.currency,
        ai.days_outstanding
      FROM vw_ar_invoices ai
      JOIN customers c ON ai.customer_id = c.customer_id
      WHERE ai.tenant_id = $1
        AND ai.payment_status IN ('unpaid', 'partial')
        AND ai.amount_outstanding > 0
      ORDER BY c.customer_name, ai.days_outstanding DESC
    `;

    const results = await this.dataSource.query(query, [params.tenant_id]);

    // Calculate aging buckets and group by customer
    const customerMap = new Map();
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

      // Group by customer
      if (!customerMap.has(r.customer_id)) {
        customerMap.set(r.customer_id, {
          customer_id: r.customer_id,
          customer_code: r.customer_code,
          customer_name: r.customer_name,
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

      const customer = customerMap.get(r.customer_id);
      customer.invoices.push(invoiceRecord);
      customer.total_outstanding += outstanding;
      customer.current += bucketAmount.current;
      customer.days_1_30 += bucketAmount.days_1_30;
      customer.days_31_60 += bucketAmount.days_31_60;
      customer.days_61_90 += bucketAmount.days_61_90;
      customer.days_90_plus += bucketAmount.days_90_plus;
    });

    const customers = Array.from(customerMap.values());

    return {
      tenant_id: params.tenant_id,
      as_of_date: asOfDate,
      generated_at: new Date().toISOString(),
      customers: customers,
      summary: {
        total_customers: customers.length,
        total_invoices: results.length,
        total_outstanding: customers.reduce((sum, c) => sum + c.total_outstanding, 0),
        current: totalCurrent,
        days_1_30: total1to30,
        days_31_60: total31to60,
        days_61_90: total61to90,
        days_90_plus: total90Plus,
      },
    };
  }

  async getDashboardKPIs(params: any): Promise<any> {
    this.logger.log(`Generating dashboard KPIs for tenant: ${params.tenant_id}`);

    const tenantId = params.tenant_id;

    // Parallel queries for better performance
    const [
      cashBalanceResult,
      trialBalanceResult,
      incomeStatsResult,
      apAgingResult,
      arAgingResult,
      recentActivityResult,
      pendingEntriesResult,
      accountCountResult,
    ] = await Promise.all([
      // 1. Cash Balance (Bank accounts 1010-1090)
      this.dataSource.query(`
        SELECT SUM(net_balance) as total_cash
        FROM trial_balance
        WHERE tenant_id = $1
          AND account_code BETWEEN '1010' AND '1090'
      `, [tenantId]),

      // 2. Trial Balance Status
      this.dataSource.query(`
        SELECT
          SUM(debit_balance) as total_debits,
          SUM(credit_balance) as total_credits,
          COUNT(*) as account_count
        FROM trial_balance
        WHERE tenant_id = $1
      `, [tenantId]),

      // 3. Income Stats (Revenue and Expenses)
      this.dataSource.query(`
        SELECT
          account_type,
          SUM(net_balance) as total
        FROM trial_balance
        WHERE tenant_id = $1
          AND account_type IN ('Revenue', 'Expense')
        GROUP BY account_type
      `, [tenantId]),

      // 4. AP Aging Summary
      this.dataSource.query(`
        SELECT
          COUNT(DISTINCT jel.dimension_1) as vendor_count,
          SUM(CASE WHEN coa.account_code = '2100' THEN jel.credit_amount - jel.debit_amount ELSE 0 END) as total_payable
        FROM journal_entry_lines jel
        JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
        WHERE jel.tenant_id = $1
          AND jel.dimension_1 IS NOT NULL
          AND coa.account_code = '2100'
      `, [tenantId]),

      // 5. AR Aging Summary
      this.dataSource.query(`
        SELECT
          COUNT(DISTINCT jel.dimension_2) as customer_count,
          SUM(CASE WHEN coa.account_code = '1200' THEN jel.debit_amount - jel.credit_amount ELSE 0 END) as total_receivable
        FROM journal_entry_lines jel
        JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
        WHERE jel.tenant_id = $1
          AND jel.dimension_2 IS NOT NULL
          AND coa.account_code = '1200'
      `, [tenantId]),

      // 6. Recent Activity (Last 10 entries)
      this.dataSource.query(`
        SELECT
          je.entry_id,
          je.entry_number,
          je.entry_date,
          je.entry_type,
          je.description,
          je.status,
          COUNT(jel.line_id) as line_count,
          SUM(jel.debit_amount) as total_debit
        FROM journal_entries je
        LEFT JOIN journal_entry_lines jel ON je.entry_id = jel.entry_id
        WHERE je.tenant_id = $1
        GROUP BY je.entry_id
        ORDER BY je.entry_date DESC, je.created_at DESC
        LIMIT 10
      `, [tenantId]),

      // 7. Pending Entries (Draft or Pending Approval)
      this.dataSource.query(`
        SELECT
          COUNT(*) as pending_count,
          SUM(CASE WHEN status = 'draft' THEN 1 ELSE 0 END) as draft_count,
          SUM(CASE WHEN status = 'pending_approval' THEN 1 ELSE 0 END) as pending_approval_count
        FROM journal_entries
        WHERE tenant_id = $1
          AND status IN ('draft', 'pending_approval')
      `, [tenantId]),

      // 8. Account Counts by Type
      this.dataSource.query(`
        SELECT
          account_type,
          COUNT(*) as count,
          COUNT(CASE WHEN ABS(net_balance) > 0.01 THEN 1 END) as non_zero_count
        FROM trial_balance
        WHERE tenant_id = $1
        GROUP BY account_type
      `, [tenantId]),
    ]);

    // Process results
    const cashBalance = parseFloat(cashBalanceResult[0]?.total_cash || 0);
    const totalDebits = parseFloat(trialBalanceResult[0]?.total_debits || 0);
    const totalCredits = parseFloat(trialBalanceResult[0]?.total_credits || 0);
    const isBalanced = Math.abs(totalDebits - totalCredits) < 0.01;

    // Calculate revenue and expenses
    let totalRevenue = 0;
    let totalExpenses = 0;
    incomeStatsResult.forEach(r => {
      if (r.account_type === 'Revenue') {
        totalRevenue = Math.abs(parseFloat(r.total || 0));
      } else if (r.account_type === 'Expense') {
        totalExpenses = Math.abs(parseFloat(r.total || 0));
      }
    });
    const netIncome = totalRevenue - totalExpenses;

    const vendorCount = parseInt(apAgingResult[0]?.vendor_count || 0);
    const totalPayable = parseFloat(apAgingResult[0]?.total_payable || 0);
    const customerCount = parseInt(arAgingResult[0]?.customer_count || 0);
    const totalReceivable = parseFloat(arAgingResult[0]?.total_receivable || 0);

    const pendingCount = parseInt(pendingEntriesResult[0]?.pending_count || 0);
    const draftCount = parseInt(pendingEntriesResult[0]?.draft_count || 0);
    const pendingApprovalCount = parseInt(pendingEntriesResult[0]?.pending_approval_count || 0);

    // Check for exceptions
    const exceptions = [];
    if (!isBalanced) {
      exceptions.push({
        type: 'balance',
        severity: 'high',
        message: `Trial balance is out of balance by ${Math.abs(totalDebits - totalCredits).toFixed(2)} AED`,
        action: 'Review journal entries for errors',
      });
    }
    if (totalPayable < 0) {
      exceptions.push({
        type: 'ap_negative',
        severity: 'medium',
        message: `Negative AP balance detected: ${totalPayable.toFixed(2)} AED`,
        action: 'Review vendor payments and invoices',
      });
    }
    if (totalReceivable < 0) {
      exceptions.push({
        type: 'ar_negative',
        severity: 'medium',
        message: `Negative AR balance detected: ${totalReceivable.toFixed(2)} AED`,
        action: 'Review customer payments and invoices',
      });
    }

    // Pending actions
    const pendingActions = [];
    if (draftCount > 0) {
      pendingActions.push({
        type: 'draft_entries',
        count: draftCount,
        message: `${draftCount} draft journal ${draftCount === 1 ? 'entry' : 'entries'} pending posting`,
        link: 'je-register.html?status=draft',
      });
    }
    if (pendingApprovalCount > 0) {
      pendingActions.push({
        type: 'pending_approval',
        count: pendingApprovalCount,
        message: `${pendingApprovalCount} ${pendingApprovalCount === 1 ? 'entry' : 'entries'} pending approval`,
        link: 'je-register.html?status=pending_approval',
      });
    }

    return {
      tenant_id: tenantId,
      generated_at: new Date().toISOString(),
      kpis: {
        financial: {
          cash_balance: cashBalance,
          total_revenue: totalRevenue,
          total_expenses: totalExpenses,
          net_income: netIncome,
          profit_margin: totalRevenue > 0 ? (netIncome / totalRevenue) * 100 : 0,
        },
        operational: {
          vendor_count: vendorCount,
          customer_count: customerCount,
          total_payable: totalPayable,
          total_receivable: totalReceivable,
          working_capital: totalReceivable - totalPayable,
        },
        accounting: {
          total_debits: totalDebits,
          total_credits: totalCredits,
          is_balanced: isBalanced,
          variance: totalDebits - totalCredits,
          account_count: parseInt(trialBalanceResult[0]?.account_count || 0),
        },
      },
      health: {
        status: exceptions.length === 0 ? 'healthy' : (exceptions.some(e => e.severity === 'high') ? 'critical' : 'warning'),
        score: Math.max(0, 100 - (exceptions.length * 20)),
        checks: {
          trial_balance: isBalanced,
          ap_balance: totalPayable >= 0,
          ar_balance: totalReceivable >= 0,
          has_activity: recentActivityResult.length > 0,
        },
      },
      exceptions: exceptions,
      pending_actions: pendingActions,
      recent_activity: recentActivityResult.map(r => ({
        entry_id: r.entry_id,
        entry_number: r.entry_number,
        entry_date: r.entry_date,
        entry_type: r.entry_type,
        description: r.description,
        status: r.status,
        line_count: parseInt(r.line_count || 0),
        amount: parseFloat(r.total_debit || 0),
      })),
      account_summary: accountCountResult.map(r => ({
        account_type: r.account_type,
        total_count: parseInt(r.count || 0),
        non_zero_count: parseInt(r.non_zero_count || 0),
      })),
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
