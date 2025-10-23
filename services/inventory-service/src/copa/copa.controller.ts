import { Controller, Get, Query, Logger } from '@nestjs/common';
import { CopaService } from './copa.service';

@Controller('copa')
export class CopaController {
  private readonly logger = new Logger(CopaController.name);

  constructor(private readonly copaService: CopaService) {}

  @Get('profitability')
  async getProfitabilityReport(@Query() query: any) {
    this.logger.log(`GET /copa/profitability - Tenant: ${query.tenant_id}`);
    return await this.copaService.getProfitabilityReport(query.tenant_id, query);
  }

  @Get('product-profitability')
  async getProductProfitability(@Query() query: any) {
    this.logger.log(`GET /copa/product-profitability - Tenant: ${query.tenant_id}`);
    return await this.copaService.getProductProfitability(query.tenant_id, query);
  }

  @Get('customer-profitability')
  async getCustomerProfitability(@Query() query: any) {
    this.logger.log(`GET /copa/customer-profitability - Tenant: ${query.tenant_id}`);
    return await this.copaService.getCustomerProfitability(query.tenant_id, query);
  }

  @Get('region-profitability')
  async getRegionProfitability(@Query() query: any) {
    this.logger.log(`GET /copa/region-profitability - Tenant: ${query.tenant_id}`);
    return await this.copaService.getRegionProfitability(query.tenant_id, query);
  }

  @Get('reconciliation')
  async getRevenueReconciliation(@Query() query: any) {
    this.logger.log(`GET /copa/reconciliation - Tenant: ${query.tenant_id}`);
    return await this.copaService.getRevenueReconciliation(
      query.tenant_id,
      query.fiscal_year,
      query.fiscal_period
    );
  }

  @Get('dashboard')
  async getCopaDashboard(@Query() query: any) {
    this.logger.log(`GET /copa/dashboard - Tenant: ${query.tenant_id}`);
    return await this.copaService.getCopaDashboard(query.tenant_id, query);
  }
}
