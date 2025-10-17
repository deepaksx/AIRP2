import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TrialBalanceEntity } from './trial-balance.entity';
import { APAgingEntity } from './ap-aging.entity';
import { ARAgingEntity } from './ar-aging.entity';

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
  ) {}

  async updateTrialBalance(event: any): Promise<void> {
    this.logger.log(`Updating trial balance for tenant: ${event.tenant_id}`);

    // In production, this would process journal entry lines and update account balances
    // For now, logging as demo mode
    this.logger.log(`Trial balance projection would be updated with event data`);
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
