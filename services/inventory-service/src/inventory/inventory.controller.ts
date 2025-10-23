import { Controller, Get, Post, Put, Delete, Body, Param, Query, Logger } from '@nestjs/common';
import { InventoryService } from './inventory.service';

@Controller('inventory')
export class InventoryController {
  private readonly logger = new Logger(InventoryController.name);

  constructor(private readonly inventoryService: InventoryService) {}

  // ===== ITEMS =====

  @Post('items')
  async createItem(@Body() createItemDto: any) {
    this.logger.log(`POST /inventory/items - Creating item: ${createItemDto.item_code}`);
    return await this.inventoryService.createItem(createItemDto);
  }

  @Get('items')
  async findAllItems(@Query() query: any) {
    this.logger.log(`GET /inventory/items - Tenant: ${query.tenant_id}`);
    return await this.inventoryService.findAllItems(query.tenant_id, query);
  }

  @Get('items/:id')
  async findItemById(@Param('id') id: string) {
    this.logger.log(`GET /inventory/items/${id}`);
    return await this.inventoryService.findItemById(id);
  }

  @Put('items/:id')
  async updateItem(@Param('id') id: string, @Body() updateItemDto: any) {
    this.logger.log(`PUT /inventory/items/${id}`);
    return await this.inventoryService.updateItem(id, updateItemDto);
  }

  @Delete('items/:id')
  async deleteItem(@Param('id') id: string) {
    this.logger.log(`DELETE /inventory/items/${id}`);
    return await this.inventoryService.deleteItem(id);
  }

  // ===== WAREHOUSES =====

  @Post('warehouses')
  async createWarehouse(@Body() createWarehouseDto: any) {
    this.logger.log(`POST /inventory/warehouses - Creating: ${createWarehouseDto.warehouse_code}`);
    return await this.inventoryService.createWarehouse(createWarehouseDto);
  }

  @Get('warehouses')
  async findAllWarehouses(@Query('tenant_id') tenantId: string) {
    this.logger.log(`GET /inventory/warehouses - Tenant: ${tenantId}`);
    return await this.inventoryService.findAllWarehouses(tenantId);
  }

  @Get('warehouses/:id')
  async findWarehouseById(@Param('id') id: string) {
    this.logger.log(`GET /inventory/warehouses/${id}`);
    return await this.inventoryService.findWarehouseById(id);
  }

  // ===== STOCK =====

  @Get('stock/by-item/:itemId')
  async getStockByItem(
    @Param('itemId') itemId: string,
    @Query('tenant_id') tenantId: string
  ) {
    this.logger.log(`GET /inventory/stock/by-item/${itemId}`);
    return await this.inventoryService.getStockByItem(tenantId, itemId);
  }

  @Get('stock/by-warehouse/:warehouseId')
  async getStockByWarehouse(
    @Param('warehouseId') warehouseId: string,
    @Query('tenant_id') tenantId: string
  ) {
    this.logger.log(`GET /inventory/stock/by-warehouse/${warehouseId}`);
    return await this.inventoryService.getStockByWarehouse(tenantId, warehouseId);
  }

  @Get('valuation')
  async getInventoryValuation(@Query('tenant_id') tenantId: string) {
    this.logger.log(`GET /inventory/valuation - Tenant: ${tenantId}`);
    return await this.inventoryService.getInventoryValuation(tenantId);
  }

  @Get('reconciliation')
  async getInventoryReconciliation(@Query('tenant_id') tenantId: string) {
    this.logger.log(`GET /inventory/reconciliation - Tenant: ${tenantId}`);
    return await this.inventoryService.getInventoryReconciliation(tenantId);
  }

  @Get('transactions')
  async getInventoryTransactions(@Query() query: any) {
    this.logger.log(`GET /inventory/transactions - Tenant: ${query.tenant_id}`);
    return await this.inventoryService.getInventoryTransactions(query.tenant_id, query);
  }
}
