import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { TrialBalanceEntity } from './trial-balance.entity';
import { APAgingEntity } from './ap-aging.entity';
import { ARAgingEntity } from './ar-aging.entity';
import { GLBalanceEntity } from './gl-balance.entity';
import { ChartOfAccountsEntity } from './chart-of-accounts.entity';

@Injectable()
export class ProjectionService {
  private readonly logger = new Logger(ProjectionService.name);

  constructor(
    @InjectRepository(TrialBalanceEntity)
    private trialBalanceRepo: Repository<TrialBalanceEntity>,
    @InjectRepository(APAgingEntity)
    private apAgingRepo: Repository<APAgingEntity>,
    @InjectRepository(ARAgingEntity)
    private arAgingRepo: Repository<ARAgingEntity>,
    @InjectRepository(GLBalanceEntity)
    private glBalanceRepo: Repository<GLBalanceEntity>,
    @InjectRepository(ChartOfAccountsEntity)
    private coaRepo: Repository<ChartOfAccountsEntity>,
    private dataSource: DataSource,
  ) {}

  async updateTrialBalance(event: any): Promise<void> {
    this.logger.log(`Updating GL balances for tenant: ${event.tenant_id}`);

    try {
      const journalEntryData = event.event_data;
      const lines = journalEntryData.lines || [];
      const entryDate = new Date(journalEntryData.entryDate);
      const fiscalYear = entryDate.getFullYear();
      const fiscalPeriod = entryDate.getMonth() + 1; // 1-12
      const currency = journalEntryData.currency || 'AED';

      for (const line of lines) {
        // Look up account_id from chart of accounts
        const coaEntry = await this.coaRepo.findOne({
          where: {
            tenant_id: event.tenant_id,
            account_code: line.accountCode,
          },
        });

        if (!coaEntry) {
          this.logger.warn(
            `Account code ${line.accountCode} not found in chart of accounts for tenant ${event.tenant_id}`
          );
          continue;
        }

        // Find or create GL balance entry
        let glBalance = await this.glBalanceRepo.findOne({
          where: {
            tenant_id: event.tenant_id,
            account_id: coaEntry.account_id,
            fiscal_year: fiscalYear,
            fiscal_period: fiscalPeriod,
            currency: currency,
          },
        });

        if (!glBalance) {
          // Create new GL balance entry
          glBalance = this.glBalanceRepo.create({
            tenant_id: event.tenant_id,
            account_id: coaEntry.account_id,
            fiscal_year: fiscalYear,
            fiscal_period: fiscalPeriod,
            currency: currency,
            debit_amount: 0,
            credit_amount: 0,
            balance: 0,
            last_event_id: event.event_id,
          });
        }

        // Update balances
        const debitAmount = parseFloat(line.debitAmount || '0');
        const creditAmount = parseFloat(line.creditAmount || '0');

        glBalance.debit_amount = parseFloat(glBalance.debit_amount.toString()) + debitAmount;
        glBalance.credit_amount = parseFloat(glBalance.credit_amount.toString()) + creditAmount;

        // Calculate balance based on normal balance type
        if (coaEntry.normal_balance === 'DEBIT') {
          glBalance.balance = glBalance.debit_amount - glBalance.credit_amount;
        } else {
          glBalance.balance = glBalance.credit_amount - glBalance.debit_amount;
        }

        glBalance.last_updated = new Date();
        glBalance.last_event_id = event.event_id;

        await this.glBalanceRepo.save(glBalance);

        this.logger.log(
          `Updated GL balance for account ${line.accountCode}: ` +
          `Debit=${glBalance.debit_amount}, Credit=${glBalance.credit_amount}, Balance=${glBalance.balance}`
        );
      }

      // Refresh the trial balance materialized view
      await this.dataSource.query('REFRESH MATERIALIZED VIEW trial_balance');
      this.logger.log(`Trial balance materialized view refreshed for event ${event.event_id}`);
    } catch (error) {
      this.logger.error(`Failed to update GL balances: ${error.message}`, error.stack);
      throw error;
    }
  }

  async updateAPAging(event: any): Promise<void> {
    this.logger.log(`Updating AP aging for tenant: ${event.tenant_id}`);

    // In production, this would calculate aging buckets and update AP aging table
    this.logger.log(`AP aging projection would be updated with event data`);
  }

  async updateARAging(event: any): Promise<void> {
    this.logger.log(`Updating AR aging for tenant: ${event.tenant_id}`);

    // In production, this would calculate aging buckets and update AR aging table
    this.logger.log(`AR aging projection would be updated with event data`);
  }

  private calculateAgingBucket(daysOutstanding: number): string {
    if (daysOutstanding <= 0) return 'current';
    if (daysOutstanding <= 30) return '1-30';
    if (daysOutstanding <= 60) return '31-60';
    if (daysOutstanding <= 90) return '61-90';
    return '90+';
  }
}
