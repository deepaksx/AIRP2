import { Entity, Column, PrimaryGeneratedColumn, ManyToOne, JoinColumn } from 'typeorm';
import { BudgetEntity } from './budget.entity';

@Entity('budget_lines')
export class BudgetLineEntity {
  @PrimaryGeneratedColumn('uuid')
  line_id: string;

  @Column({ type: 'uuid' })
  budget_id: string;

  @Column({ type: 'uuid' })
  account_id: string;

  @Column({ type: 'varchar', length: 20 })
  account_code: string;

  @Column({ type: 'varchar', length: 200 })
  account_name: string;

  @Column({ type: 'integer' })
  period_month: number; // 1-12

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  budgeted_amount: number;

  @Column({ type: 'numeric', precision: 18, scale: 2, default: 0 })
  actual_amount: number;

  @Column({ type: 'numeric', precision: 18, scale: 2, default: 0 })
  variance_amount: number;

  @Column({ type: 'numeric', precision: 5, scale: 2, default: 0 })
  variance_percentage: number;

  @Column({ type: 'text', nullable: true })
  notes: string;

  @ManyToOne(() => BudgetEntity, budget => budget.lines)
  @JoinColumn({ name: 'budget_id' })
  budget: BudgetEntity;
}
