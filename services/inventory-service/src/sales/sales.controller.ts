import { Controller, Get, Post, Body, Param, Query, Logger } from '@nestjs/common';
import { SalesService } from './sales.service';

@Controller('sales')
export class SalesController {
  private readonly logger = new Logger(SalesController.name);

  constructor(private readonly salesService: SalesService) {}

  // ===== SALES ORDERS =====

  @Post('sales-orders')
  async createSO(@Body() createSODto: any) {
    this.logger.log(`POST /sales/sales-orders - Creating SO: ${createSODto.so_number}`);
    return await this.salesService.createSO(createSODto);
  }

  @Get('sales-orders')
  async findAllSOs(@Query() query: any) {
    this.logger.log(`GET /sales/sales-orders - Tenant: ${query.tenant_id}`);
    return await this.salesService.findAllSOs(query.tenant_id, query);
  }

  @Get('sales-orders/:id')
  async findSOById(@Param('id') id: string) {
    this.logger.log(`GET /sales/sales-orders/${id}`);
    return await this.salesService.findSOById(id);
  }

  @Get('sales-orders/outstanding')
  async getOutstandingSOs(@Query('tenant_id') tenantId: string) {
    this.logger.log(`GET /sales/sales-orders/outstanding - Tenant: ${tenantId}`);
    return await this.salesService.getOutstandingSOs(tenantId);
  }

  // ===== SALES DELIVERIES =====

  @Post('deliveries')
  async createSalesDelivery(@Body() deliveryData: any) {
    this.logger.log(`POST /sales/deliveries - Creating delivery: ${deliveryData.delivery_number}`);
    return await this.salesService.createSalesDelivery(deliveryData);
  }

  @Post('deliveries/:id/post')
  async postSalesDelivery(@Param('id') id: string, @Body() postData: any) {
    this.logger.log(`POST /sales/deliveries/${id}/post`);
    return await this.salesService.postSalesDelivery({
      ...postData,
      delivery_id: id,
    });
  }
}
