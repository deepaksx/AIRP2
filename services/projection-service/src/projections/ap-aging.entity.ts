import { Entity, Column, PrimaryGeneratedColumn, Index } from 'typeorm';

@Entity('ap_aging')
@Index(['tenant_id', 'vendor_id'])
@Index(['tenant_id', 'invoice_id', 'as_of_date'], { unique: true })
export class APAgingEntity {
  @PrimaryGeneratedColumn('uuid')
  aging_id: string;

  @Column({ type: 'uuid' })
  @Index()
  tenant_id: string;

  @Column({ type: 'uuid' })
  @Index()
  vendor_id: string;

  @Column({ type: 'uuid' })
  invoice_id: string;

  @Column({ type: 'char', length: 3 })
  currency: string;

  @Column({ type: 'numeric', precision: 20, scale: 4 })
  total_outstanding: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  current_amount: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  bucket_30: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  bucket_60: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  bucket_90: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  bucket_120_plus: number;

  @Column({ type: 'date' })
  @Index()
  as_of_date: Date;

  @Column({ type: 'timestamptz', default: () => 'CURRENT_TIMESTAMP' })
  last_updated: Date;
}
