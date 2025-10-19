import { Controller, Get, Post, Put, Body, Param, Query, Logger } from '@nestjs/common';
import { TreasuryService } from './treasury.service';

@Controller()
export class TreasuryController {
  private readonly logger = new Logger(TreasuryController.name);

  constructor(private readonly treasuryService: TreasuryService) {}

  // Bank Accounts endpoints
  @Get('bank-accounts')
  async getBankAccounts(@Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching bank accounts for tenant: ${tenantId}`);
    return this.treasuryService.getBankAccounts(tenantId);
  }

  @Get('bank-accounts/:id')
  async getBankAccount(@Param('id') id: string, @Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching bank account ${id} for tenant: ${tenantId}`);
    return this.treasuryService.getBankAccount(id, tenantId);
  }

  @Post('bank-accounts')
  async createBankAccount(@Body() accountData: any) {
    this.logger.log(`Creating bank account: ${accountData.bank_name}`);
    return this.treasuryService.createBankAccount(accountData);
  }

  @Put('bank-accounts/:id')
  async updateBankAccount(@Param('id') id: string, @Body() accountData: any) {
    this.logger.log(`Updating bank account ${id}`);
    return this.treasuryService.updateBankAccount(id, accountData);
  }

  // Legacy treasury endpoints
  @Get('treasury/accounts')
  async getLegacyBankAccounts(@Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching bank accounts for tenant (legacy): ${tenantId}`);
    return this.treasuryService.getBankAccounts(tenantId);
  }

  @Get('treasury/transactions')
  async getTransactions(@Query('tenant_id') tenantId: string, @Query('account_id') accountId?: string) {
    this.logger.log(`Fetching transactions for tenant: ${tenantId}`);
    return this.treasuryService.getTransactions(tenantId, accountId);
  }

  @Get('treasury/forecast')
  async getCashFlowForecast(@Query('tenant_id') tenantId: string, @Query('days') days: number = 30) {
    this.logger.log(`Fetching cash flow forecast for ${days} days`);
    return this.treasuryService.getCashFlowForecast(tenantId, days);
  }

  @Post('treasury/reconcile')
  async reconcileTransactions(@Body() reconciliationData: any) {
    this.logger.log(`Reconciling transactions`);
    return this.treasuryService.reconcileTransactions(reconciliationData);
  }
}
