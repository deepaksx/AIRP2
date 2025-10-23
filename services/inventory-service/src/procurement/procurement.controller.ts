import { Controller, Get, Post, Body, Param, Query, Logger } from '@nestjs/common';
import { ProcurementService } from './procurement.service';

@Controller('procurement')
export class ProcurementController {
  private readonly logger = new Logger(ProcurementController.name);

  constructor(private readonly procurementService: ProcurementService) {}

  // ===== PURCHASE ORDERS =====

  @Post('purchase-orders')
  async createPO(@Body() createPODto: any) {
    this.logger.log(`POST /procurement/purchase-orders - Creating PO: ${createPODto.po_number}`);
    return await this.procurementService.createPO(createPODto);
  }

  @Get('purchase-orders')
  async findAllPOs(@Query() query: any) {
    this.logger.log(`GET /procurement/purchase-orders - Tenant: ${query.tenant_id}`);
    return await this.procurementService.findAllPOs(query.tenant_id, query);
  }

  @Get('purchase-orders/:id')
  async findPOById(@Param('id') id: string) {
    this.logger.log(`GET /procurement/purchase-orders/${id}`);
    return await this.procurementService.findPOById(id);
  }

  @Get('purchase-orders/outstanding')
  async getOutstandingPOs(@Query('tenant_id') tenantId: string) {
    this.logger.log(`GET /procurement/purchase-orders/outstanding - Tenant: ${tenantId}`);
    return await this.procurementService.getOutstandingPOs(tenantId);
  }

  // ===== GOODS RECEIPTS =====

  @Post('goods-receipts')
  async createGoodsReceipt(@Body() grData: any) {
    this.logger.log(`POST /procurement/goods-receipts - Creating GR: ${grData.gr_number}`);
    return await this.procurementService.createGoodsReceipt(grData);
  }

  @Post('goods-receipts/:id/post')
  async postGoodsReceipt(@Param('id') id: string, @Body() postData: any) {
    this.logger.log(`POST /procurement/goods-receipts/${id}/post`);
    return await this.procurementService.postGoodsReceipt({
      ...postData,
      gr_id: id,
    });
  }
}
