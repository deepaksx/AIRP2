import { Controller, Get, Post, Body, Param, Query, Logger } from '@nestjs/common';
import { InvoicesService } from './invoices.service';

@Controller('invoices')
export class InvoicesController {
  private readonly logger = new Logger(InvoicesController.name);

  constructor(private readonly invoicesService: InvoicesService) {}

  @Get()
  async findAll(@Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching all invoices for tenant: ${tenantId}`);
    return this.invoicesService.findAll(tenantId);
  }

  @Get(':id')
  async findOne(@Param('id') id: string, @Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching invoice ${id} for tenant: ${tenantId}`);
    return this.invoicesService.findOne(id, tenantId);
  }

  @Post()
  async create(@Body() invoiceData: any) {
    this.logger.log(`Creating invoice: ${invoiceData.invoice_number}`);
    return this.invoicesService.create(invoiceData);
  }
}
