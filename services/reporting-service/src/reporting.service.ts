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

    const query = `
      SELECT account_code, account_name, account_type,
             debit_balance, credit_balance, net_balance
      FROM trial_balance
      WHERE tenant_id = $1
        AND period_end_date = $2
      ORDER BY account_code
    `;

    const results = await this.dataSource.query(query, [
      params.tenant_id,
      params.period_end_date || new Date(),
    ]);

    return {
      tenant_id: params.tenant_id,
      period_end_date: params.period_end_date,
      accounts: results,
      total_debits: results.reduce((sum, r) => sum + parseFloat(r.debit_balance || 0), 0),
      total_credits: results.reduce((sum, r) => sum + parseFloat(r.credit_balance || 0), 0),
    };
  }

  async getProfitLoss(params: any): Promise<any> {
    this.logger.log(`Generating P&L statement`);

    return {
      tenant_id: params.tenant_id,
      period_start: params.period_start,
      period_end: params.period_end,
      revenue: [],
      expenses: [],
      net_income: 0,
    };
  }

  async getBalanceSheet(params: any): Promise<any> {
    this.logger.log(`Generating balance sheet`);

    return {
      tenant_id: params.tenant_id,
      as_of_date: params.as_of_date,
      assets: [],
      liabilities: [],
      equity: [],
    };
  }

  async getCashFlow(params: any): Promise<any> {
    this.logger.log(`Generating cash flow statement`);

    return {
      tenant_id: params.tenant_id,
      period_start: params.period_start,
      period_end: params.period_end,
      operating_activities: [],
      investing_activities: [],
      financing_activities: [],
    };
  }

  async getAPAging(params: any): Promise<any> {
    this.logger.log(`Fetching AP aging report`);

    const query = `
      SELECT vendor_name, invoice_number, invoice_date, due_date,
             outstanding_amount, days_outstanding, aging_bucket
      FROM ap_aging
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
