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

  @Column({ type: 'varchar', length: 3, default: 'AED' })
  currency_code: string;

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  subtotal_amount: number;

  @Column({ type: 'numeric', precision: 18, scale: 2, default: 0 })
  tax_amount: number;

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  total_amount: number;

  @Column({ type: 'numeric', precision: 18, scale: 2, default: 0 })
  paid_amount: number;

  @Column({ type: 'varchar', length: 20, default: 'pending' })
  status: string;

  @Column({ type: 'text', nullable: true })
  notes: string;

  @Column({ type: 'boolean', default: false })
  ai_classified: boolean;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;

  @OneToMany(() => APInvoiceLineEntity, line => line.invoice)
  lines: APInvoiceLineEntity[];

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
