import { Entity, Column, PrimaryGeneratedColumn, Index } from 'typeorm';

@Entity('gl_balances')
@Index(['tenant_id', 'account_id', 'fiscal_year', 'fiscal_period', 'currency'], { unique: true })
export class GLBalanceEntity {
  @PrimaryGeneratedColumn('uuid')
  balance_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'uuid' })
  account_id: string;

  @Column({ type: 'int' })
  fiscal_year: number;

  @Column({ type: 'int' })
  fiscal_period: number;

  @Column({ type: 'char', length: 3 })
  currency: string;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  debit_amount: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  credit_amount: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  balance: number;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  last_updated: Date;

  @Column({ type: 'uuid', nullable: true })
  last_event_id: string;
}
