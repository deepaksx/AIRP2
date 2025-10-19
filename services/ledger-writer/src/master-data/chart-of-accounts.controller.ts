import { Controller, Get, Query, Param } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery, ApiParam } from '@nestjs/swagger';
import { ChartOfAccountsService } from './chart-of-accounts.service';

@ApiTags('chart-of-accounts')
@Controller('chart-of-accounts')
export class ChartOfAccountsController {
  constructor(private readonly coaService: ChartOfAccountsService) {}

  @Get()
  @ApiOperation({ summary: 'Get chart of accounts for a tenant' })
  @ApiQuery({ name: 'tenant_id', description: 'Tenant UUID', required: true })
  @ApiQuery({ name: 'includeInactive', description: 'Include inactive accounts', required: false })
  @ApiResponse({ status: 200, description: 'Chart of accounts retrieved' })
  @ApiResponse({ status: 400, description: 'Missing or invalid tenant_id' })
  async getChartOfAccounts(
    @Query('tenant_id') tenantId: string,
    @Query('includeInactive') includeInactive?: string,
  ) {
    if (!tenantId || tenantId.trim() === '') {
      throw new Error('tenant_id is required');
    }
    if (includeInactive === 'true') {
      return this.coaService.getAllChartOfAccounts(tenantId);
    }
    return this.coaService.getChartOfAccounts(tenantId);
  }

  @Get('by-code/:accountCode')
  @ApiOperation({ summary: 'Get account by code' })
  @ApiParam({ name: 'accountCode', description: 'Account code' })
  @ApiQuery({ name: 'tenant_id', description: 'Tenant UUID', required: true })
  @ApiResponse({ status: 200, description: 'Account retrieved' })
  @ApiResponse({ status: 400, description: 'Missing or invalid tenant_id' })
  @ApiResponse({ status: 404, description: 'Account not found' })
  async getAccountByCode(
    @Param('accountCode') accountCode: string,
    @Query('tenant_id') tenantId: string,
  ) {
    if (!tenantId || tenantId.trim() === '') {
      throw new Error('tenant_id is required');
    }
    return this.coaService.getAccountByCode(tenantId, accountCode);
  }

  @Get('by-id/:accountId')
  @ApiOperation({ summary: 'Get account by ID' })
  @ApiParam({ name: 'accountId', description: 'Account UUID' })
  @ApiResponse({ status: 200, description: 'Account retrieved' })
  @ApiResponse({ status: 404, description: 'Account not found' })
  async getAccountById(@Param('accountId') accountId: string) {
    return this.coaService.getAccountById(accountId);
  }

  @Get('by-type/:accountType')
  @ApiOperation({ summary: 'Get accounts by type' })
  @ApiParam({ name: 'accountType', description: 'Account type (asset, liability, etc.)' })
  @ApiQuery({ name: 'tenant_id', description: 'Tenant UUID', required: true })
  @ApiResponse({ status: 200, description: 'Accounts retrieved' })
  @ApiResponse({ status: 400, description: 'Missing or invalid tenant_id' })
  async getAccountsByType(
    @Param('accountType') accountType: string,
    @Query('tenant_id') tenantId: string,
  ) {
    if (!tenantId || tenantId.trim() === '') {
      throw new Error('tenant_id is required');
    }
    return this.coaService.getAccountsByType(tenantId, accountType);
  }
}
