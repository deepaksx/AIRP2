import { Controller, Get, Post, Put, Body, Param, Query, Logger } from '@nestjs/common';
import { CustomersService } from './customers.service';

@Controller('customers')
export class CustomersController {
  private readonly logger = new Logger(CustomersController.name);

  constructor(private readonly customersService: CustomersService) {}

  @Get()
  async findAll(@Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching all customers for tenant: ${tenantId}`);
    return this.customersService.findAll(tenantId);
  }

  @Get(':id')
  async findOne(@Param('id') id: string, @Query('tenant_id') tenantId: string) {
    this.logger.log(`Fetching customer ${id} for tenant: ${tenantId}`);
    return this.customersService.findOne(id, tenantId);
  }

  @Post()
  async create(@Body() customerData: any) {
    this.logger.log(`Creating customer: ${customerData.customer_name}`);
    return this.customersService.create(customerData);
  }

  @Put(':id')
  async update(@Param('id') id: string, @Body() customerData: any) {
    this.logger.log(`Updating customer ${id}`);
    return this.customersService.update(id, customerData);
  }
}
