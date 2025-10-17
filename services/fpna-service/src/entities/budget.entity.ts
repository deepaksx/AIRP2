import { Entity, Column, PrimaryGeneratedColumn, Index, CreateDateColumn, UpdateDateColumn, OneToMany } from 'typeorm';
import { BudgetLineEntity } from './budget-line.entity';

@Entity('budgets')
@Index(['tenant_id'])
export class BudgetEntity {
  @PrimaryGeneratedColumn('uuid')
  budget_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'varchar', length: 200 })
  budget_name: string;

  @Column({ type: 'integer' })
  fiscal_year: number;

  @Column({ type: 'date' })
  period_start: Date;

  @Column({ type: 'date' })
  period_end: Date;

  @Column({ type: 'varchar', length: 20, default: 'draft' })
  status: string; // draft, approved, active, closed

  @Column({ type: 'varchar', length: 3, default: 'AED' })
  currency_code: string;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;

  @OneToMany(() => BudgetLineEntity, line => line.budget)
  lines: BudgetLineEntity[];

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
