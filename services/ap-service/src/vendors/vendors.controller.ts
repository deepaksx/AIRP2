import { Controller, Get, Post, Put, Body, Param, Query, Logger } from '@nestjs/common';
import { VendorsService } from './vendors.service';

@Controller('vendors')
export class VendorsController {
  private readonly logger = new Logger(VendorsController.name);

  constructor(private readonly vendorsService: VendorsService) {}

  @Get()
  async findAll(@Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching all vendors for tenant: ${tenantId}`);
    return this.vendorsService.findAll(tenantId);
  }

  @Get(':id')
  async findOne(@Param('id') id: string, @Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching vendor ${id} for tenant: ${tenantId}`);
    return this.vendorsService.findOne(id, tenantId);
  }

  @Post()
  async create(@Body() vendorData: any) {
    this.logger.log(`Creating vendor: ${vendorData.vendor_name}`);
    return this.vendorsService.create(vendorData);
  }

  @Put(':id')
  async update(@Param('id') id: string, @Body() vendorData: any) {
    this.logger.log(`Updating vendor ${id}`);
    return this.vendorsService.update(id, vendorData);
  }
}
