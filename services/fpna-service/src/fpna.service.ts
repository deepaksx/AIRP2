import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BudgetEntity } from './entities/budget.entity';
import { BudgetLineEntity } from './entities/budget-line.entity';

@Injectable()
export class FPnAService {
  private readonly logger = new Logger(FPnAService.name);

  constructor(
    @InjectRepository(BudgetEntity)
    private budgetRepo: Repository<BudgetEntity>,
    @InjectRepository(BudgetLineEntity)
    private budgetLineRepo: Repository<BudgetLineEntity>,
  ) {}

  async getBudgets(tenantId: string): Promise<BudgetEntity[]> {
    return this.budgetRepo.find({
      where: { tenant_id: tenantId },
      order: { fiscal_year: 'DESC' },
    });
  }

  async getBudget(id: string, tenantId: string): Promise<BudgetEntity> {
    return this.budgetRepo.findOne({
      where: { budget_id: id, tenant_id: tenantId },
      relations: ['lines'],
    });
  }

  async createBudget(budgetData: Partial<BudgetEntity>): Promise<BudgetEntity> {
    const budget = this.budgetRepo.create(budgetData);
    return this.budgetRepo.save(budget);
  }

  async getVarianceAnalysis(tenantId: string, fiscalYear: number): Promise<any> {
    this.logger.log(`Generating variance analysis for tenant ${tenantId}, FY${fiscalYear}`);

    // In production, this would query the variance_analysis materialized view
    return {
      fiscal_year: fiscalYear,
      total_budgeted: 0,
      total_actual: 0,
      total_variance: 0,
      variance_percentage: 0,
      analysis_date: new Date().toISOString(),
    };
  }
}
