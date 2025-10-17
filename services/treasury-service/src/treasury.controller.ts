import { Controller, Get, Post, Body, Param, Query, Logger } from '@nestjs/common';
import { TreasuryService } from './treasury.service';

@Controller('treasury')
export class TreasuryController {
  private readonly logger = new Logger(TreasuryController.name);

  constructor(private readonly treasuryService: TreasuryService) {}

  @Get('accounts')
  async getBankAccounts(@Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching bank accounts for tenant: ${tenantId}`);
    return this.treasuryService.getBankAccounts(tenantId);
  }

  @Get('transactions')
  async getTransactions(@Query('tenant_id') tenantId: string, @Query('account_id') accountId?: string) {
    this.logger.log(`Fetching transactions for tenant: ${tenantId}`);
    return this.treasuryService.getTransactions(tenantId, accountId);
  }

  @Get('forecast')
  async getCashFlowForecast(@Query('tenant_id') tenantId: string, @Query('days') days: number = 30) {
    this.logger.log(`Fetching cash flow forecast for ${days} days`);
    return this.treasuryService.getCashFlowForecast(tenantId, days);
  }

  @Post('reconcile')
  async reconcileTransactions(@Body() reconciliationData: any) {
    this.logger.log(`Reconciling transactions`);
    return this.treasuryService.reconcileTransactions(reconciliationData);
  }
}
