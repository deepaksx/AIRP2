import { Controller, Get, Query, Logger, Res, Post, Body } from '@nestjs/common';
import { Response } from 'express';
import { ReportingService } from './reporting.service';

@Controller('reports')
export class ReportingController {
  private readonly logger = new Logger(ReportingController.name);

  constructor(private readonly reportingService: ReportingService) {}

  @Get('trial-balance')
  async getTrialBalance(@Query() params: any) {
    this.logger.log(`Generating trial balance for tenant: ${params.tenant_id}`);
    return this.reportingService.getTrialBalance(params);
  }

  @Get('profit-loss')
  async getProfitLoss(@Query() params: any) {
    this.logger.log(`Generating P&L statement for tenant: ${params.tenant_id}`);
    return this.reportingService.getProfitLoss(params);
  }

  @Get('balance-sheet')
  async getBalanceSheet(@Query() params: any) {
    this.logger.log(`Generating balance sheet for tenant: ${params.tenant_id}`);
    return this.reportingService.getBalanceSheet(params);
  }

  @Get('cash-flow')
  async getCashFlow(@Query() params: any) {
    this.logger.log(`Generating cash flow statement for tenant: ${params.tenant_id}`);
    return this.reportingService.getCashFlow(params);
  }

  @Get('aging/ap')
  async getAPAging(@Query() params: any) {
    this.logger.log(`Generating AP aging report for tenant: ${params.tenant_id}`);
    return this.reportingService.getAPAging(params);
  }

  @Get('aging/ar')
  async getARAging(@Query() params: any) {
    this.logger.log(`Generating AR aging report for tenant: ${params.tenant_id}`);
    return this.reportingService.getARAging(params);
  }

  @Get('vendor-ledger')
  async getVendorLedger(@Query() params: any) {
    this.logger.log(`Generating vendor ledger for tenant: ${params.tenant_id}, vendor: ${params.vendor_id}`);
    return this.reportingService.getVendorLedger(params);
  }

  @Get('vendor-transactions')
  async getVendorTransactions(@Query() params: any) {
    this.logger.log(`Generating vendor transaction history for tenant: ${params.tenant_id}, vendor: ${params.vendor_id || 'all'}`);
    return this.reportingService.getVendorTransactions(params);
  }

  @Get('customer-ledger')
  async getCustomerLedger(@Query() params: any) {
    this.logger.log(`Generating customer ledger for tenant: ${params.tenant_id}, customer: ${params.customer_id}`);
    return this.reportingService.getCustomerLedger(params);
  }

  @Get('account-balances')
  async getAccountBalances(@Query() params: any) {
    this.logger.log(`Generating account balances for tenant: ${params.tenant_id}`);
    return this.reportingService.getAccountBalances(params);
  }

  @Get('income-statement')
  async getIncomeStatement(@Query() params: any) {
    this.logger.log(`Generating income statement for tenant: ${params.tenant_id}`);
    return this.reportingService.getIncomeStatement(params);
  }

  @Get('export/excel')
  async exportToExcel(@Query() params: any, @Res() res: Response) {
    this.logger.log(`Exporting report to Excel: ${params.report_type}`);
    const buffer = await this.reportingService.exportToExcel(params);

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=report_${Date.now()}.xlsx`);
    res.send(buffer);
  }
}

@Controller('api')
export class QueryController {
  private readonly logger = new Logger(QueryController.name);

  constructor(private readonly reportingService: ReportingService) {}

  @Post('query')
  async executeQuery(@Body() body: { query: string; params?: any[] }) {
    this.logger.log(`Executing query: ${body.query.substring(0, 100)}...`);
    return this.reportingService.executeQuery(body.query, body.params || []);
  }
}
