import { Controller, Get, Post, Body, Param, Query, Logger } from '@nestjs/common';
import { FPnAService } from './fpna.service';

@Controller('fpna')
export class FPnAController {
  private readonly logger = new Logger(FPnAController.name);

  constructor(private readonly fpnaService: FPnAService) {}

  @Get('budgets')
  async getBudgets(@Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching budgets for tenant: ${tenantId}`);
    return this.fpnaService.getBudgets(tenantId);
  }

  @Get('budgets/:id')
  async getBudget(@Param('id') id: string, @Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching budget ${id}`);
    return this.fpnaService.getBudget(id, tenantId);
  }

  @Post('budgets')
  async createBudget(@Body() budgetData: any) {
    this.logger.log(`Creating budget: ${budgetData.budget_name}`);
    return this.fpnaService.createBudget(budgetData);
  }

  @Get('variance-analysis')
  async getVarianceAnalysis(@Query('tenant_id') tenantId: string, @Query('fiscal_year') fiscalYear: number) {
    this.logger.log(`Fetching variance analysis for FY${fiscalYear}`);
    return this.fpnaService.getVarianceAnalysis(tenantId, fiscalYear);
  }
}
