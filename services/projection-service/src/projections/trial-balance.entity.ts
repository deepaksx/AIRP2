import { Entity, Column, PrimaryColumn, Index } from 'typeorm';

@Entity('trial_balance')
@Index(['tenant_id', 'period_end_date'])
export class TrialBalanceEntity {
  @PrimaryColumn({ type: 'uuid' })
  tenant_id: string;

  @PrimaryColumn({ type: 'uuid' })
  account_id: string;

  @PrimaryColumn({ type: 'date' })
  period_end_date: Date;

  @Column({ type: 'varchar', length: 20 })
  account_code: string;

  @Column({ type: 'varchar', length: 200 })
  account_name: string;

  @Column({ type: 'varchar', length: 50 })
  account_type: string;

  @Column({ type: 'numeric', precision: 18, scale: 2, default: 0 })
  debit_balance: number;

  @Column({ type: 'numeric', precision: 18, scale: 2, default: 0 })
  credit_balance: number;

  @Column({ type: 'numeric', precision: 18, scale: 2, default: 0 })
  net_balance: number;

  @Column({ type: 'varchar', length: 3 })
  currency_code: string;

  @Column({ type: 'timestamptz' })
  last_updated: Date;
}
