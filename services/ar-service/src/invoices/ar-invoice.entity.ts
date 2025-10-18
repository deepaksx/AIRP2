import { Entity, Column, PrimaryGeneratedColumn, Index, CreateDateColumn, UpdateDateColumn, OneToMany } from 'typeorm';
import { ARInvoiceLineEntity } from './ar-invoice-line.entity';

@Entity('ar_invoices')
@Index(['tenant_id'])
@Index(['customer_id'])
export class ARInvoiceEntity {
  @PrimaryGeneratedColumn('uuid')
  invoice_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'uuid' })
  customer_id: string;

  @Column({ type: 'varchar', length: 50 })
  invoice_number: string;

  @Column({ type: 'date' })
  invoice_date: Date;

  @Column({ type: 'date' })
  due_date: Date;

  @Column({ type: 'char', length: 3, default: 'AED' })
  currency: string;

  @Column({ type: 'numeric', precision: 18, scale: 4 })
  subtotal: number;

  @Column({ type: 'numeric', precision: 18, scale: 4, default: 0 })
  tax_amount: number;

  @Column({ type: 'numeric', precision: 18, scale: 4 })
  total_amount: number;

  @Column({ type: 'numeric', precision: 18, scale: 4, default: 0 })
  amount_paid: number;

  @Column({ type: 'numeric', precision: 18, scale: 4 })
  amount_outstanding: number;

  @Column({ type: 'varchar', length: 20, default: 'issued' })
  status: string;

  @Column({ type: 'text', nullable: true })
  notes: string;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;

  @OneToMany(() => ARInvoiceLineEntity, line => line.invoice)
  lines: ARInvoiceLineEntity[];

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
