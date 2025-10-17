import { Entity, Column, PrimaryGeneratedColumn, Index } from 'typeorm';

@Entity('ar_aging')
@Index(['tenant_id', 'customer_id'])
export class ARAgingEntity {
  @PrimaryGeneratedColumn('uuid')
  aging_id: string;

  @Column({ type: 'uuid' })
  @Index()
  tenant_id: string;

  @Column({ type: 'uuid' })
  customer_id: string;

  @Column({ type: 'varchar', length: 200 })
  customer_name: string;

  @Column({ type: 'uuid' })
  invoice_id: string;

  @Column({ type: 'varchar', length: 50 })
  invoice_number: string;

  @Column({ type: 'date' })
  invoice_date: Date;

  @Column({ type: 'date' })
  due_date: Date;

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  invoice_amount: number;

  @Column({ type: 'numeric', precision: 18, scale: 2, default: 0 })
  paid_amount: number;

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  outstanding_amount: number;

  @Column({ type: 'integer' })
  days_outstanding: number;

  @Column({ type: 'varchar', length: 20 })
  aging_bucket: string;

  @Column({ type: 'varchar', length: 3 })
  currency_code: string;

  @Column({ type: 'timestamptz' })
  last_updated: Date;
}
