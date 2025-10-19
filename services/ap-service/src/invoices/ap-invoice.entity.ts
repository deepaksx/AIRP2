import { Entity, Column, PrimaryGeneratedColumn, Index, CreateDateColumn, UpdateDateColumn, OneToMany } from 'typeorm';
import { APInvoiceLineEntity } from './ap-invoice-line.entity';

@Entity('ap_invoices')
@Index(['tenant_id'])
@Index(['vendor_id'])
export class APInvoiceEntity {
  @PrimaryGeneratedColumn('uuid')
  invoice_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'uuid' })
  vendor_id: string;

  @Column({ type: 'varchar', length: 50 })
  invoice_number: string;

  @Column({ type: 'date' })
  invoice_date: Date;

  @Column({ type: 'date' })
  due_date: Date;

  @Column({ type: 'char', length: 3, default: 'AED' })
  currency: string;

  @Column({ type: 'numeric', precision: 20, scale: 4 })
  subtotal: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  tax_amount: number;

  @Column({ type: 'numeric', precision: 20, scale: 4 })
  total_amount: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  amount_paid: number;

  @Column({ type: 'numeric', precision: 20, scale: 4 })
  amount_outstanding: number;

  @Column({ type: 'varchar', length: 20, default: 'draft' })
  status: string;

  @Column({ type: 'varchar', length: 20, default: 'pending' })
  approval_status: string;

  @Column({ type: 'varchar', length: 20, default: 'unpaid' })
  payment_status: string;

  @Column({ type: 'jsonb', nullable: true })
  ai_extracted_data: any;

  @Column({ type: 'numeric', precision: 5, scale: 4, nullable: true })
  ai_confidence_score: number;

  @Column({ type: 'uuid', nullable: true })
  approved_by: string;

  @Column({ type: 'timestamptz', nullable: true })
  approved_at: Date;

  @Column({ type: 'timestamptz', nullable: true })
  paid_at: Date;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;

  @OneToMany(() => APInvoiceLineEntity, line => line.invoice)
  lines: APInvoiceLineEntity[];

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
