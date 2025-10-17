import { Entity, Column, PrimaryGeneratedColumn, Index } from 'typeorm';

@Entity('ap_aging')
@Index(['tenant_id', 'vendor_id'])
export class APAgingEntity {
  @PrimaryGeneratedColumn('uuid')
  aging_id: string;

  @Column({ type: 'uuid' })
  @Index()
  tenant_id: string;

  @Column({ type: 'uuid' })
  vendor_id: string;

  @Column({ type: 'varchar', length: 200 })
  vendor_name: string;

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
  aging_bucket: string; // current, 1-30, 31-60, 61-90, 90+

  @Column({ type: 'varchar', length: 3 })
  currency_code: string;

  @Column({ type: 'timestamptz' })
  last_updated: Date;
}
