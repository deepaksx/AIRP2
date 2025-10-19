import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ChartOfAccountsEntity } from './chart-of-accounts.entity';

@Injectable()
export class ChartOfAccountsService {
  constructor(
    @InjectRepository(ChartOfAccountsEntity)
    private readonly coaRepository: Repository<ChartOfAccountsEntity>,
  ) {}

  async getChartOfAccounts(tenantId: string): Promise<ChartOfAccountsEntity[]> {
    return this.coaRepository.find({
      where: { tenant_id: tenantId, status: 'active' },
      order: { account_code: 'ASC' },
    });
  }

  async getAllChartOfAccounts(tenantId: string): Promise<ChartOfAccountsEntity[]> {
    return this.coaRepository.find({
      where: { tenant_id: tenantId },
      order: { account_code: 'ASC' },
    });
  }

  async getAccountByCode(
    tenantId: string,
    accountCode: string,
  ): Promise<ChartOfAccountsEntity> {
    return this.coaRepository.findOne({
      where: { tenant_id: tenantId, account_code: accountCode },
    });
  }

  async getAccountById(accountId: string): Promise<ChartOfAccountsEntity> {
    return this.coaRepository.findOne({
      where: { account_id: accountId },
    });
  }

  async getAccountsByType(
    tenantId: string,
    accountType: string,
  ): Promise<ChartOfAccountsEntity[]> {
    return this.coaRepository.find({
      where: { tenant_id: tenantId, account_type: accountType, status: 'active' },
      order: { account_code: 'ASC' },
    });
  }
}
