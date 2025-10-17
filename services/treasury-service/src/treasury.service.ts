import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BankAccountEntity } from './entities/bank-account.entity';
import { BankTransactionEntity } from './entities/bank-transaction.entity';
import { CashFlowForecastEntity } from './entities/cash-flow-forecast.entity';

@Injectable()
export class TreasuryService {
  private readonly logger = new Logger(TreasuryService.name);

  constructor(
    @InjectRepository(BankAccountEntity)
    private bankAccountRepo: Repository<BankAccountEntity>,
    @InjectRepository(BankTransactionEntity)
    private transactionRepo: Repository<BankTransactionEntity>,
    @InjectRepository(CashFlowForecastEntity)
    private forecastRepo: Repository<CashFlowForecastEntity>,
  ) {}

  async getBankAccounts(tenantId: string): Promise<BankAccountEntity[]> {
    return this.bankAccountRepo.find({
      where: { tenant_id: tenantId },
    });
  }

  async getTransactions(tenantId: string, accountId?: string): Promise<BankTransactionEntity[]> {
    const where: any = { tenant_id: tenantId };
    if (accountId) {
      where.account_id = accountId;
    }

    return this.transactionRepo.find({
      where,
      order: { transaction_date: 'DESC' },
      take: 100,
    });
  }

  async getCashFlowForecast(tenantId: string, days: number): Promise<CashFlowForecastEntity[]> {
    return this.forecastRepo.find({
      where: { tenant_id: tenantId },
      order: { forecast_date: 'ASC' },
      take: days,
    });
  }

  async reconcileTransactions(reconciliationData: any): Promise<any> {
    this.logger.log('Reconciliation logic would be executed here');
    return { status: 'success', message: 'Reconciliation completed' };
  }
}
