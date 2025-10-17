import { Entity, Column, PrimaryGeneratedColumn, ManyToOne, JoinColumn } from 'typeorm';
import { APInvoiceEntity } from './ap-invoice.entity';

@Entity('ap_invoice_lines')
export class APInvoiceLineEntity {
  @PrimaryGeneratedColumn('uuid')
  line_id: string;

  @Column({ type: 'uuid' })
  invoice_id: string;

  @Column({ type: 'integer' })
  line_number: number;

  @Column({ type: 'text' })
  description: string;

  @Column({ type: 'uuid', nullable: true })
  account_id: string;

  @Column({ type: 'varchar', length: 20, nullable: true })
  account_code: string;

  @Column({ type: 'numeric', precision: 18, scale: 6, default: 1 })
  quantity: number;

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  unit_price: number;

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  line_amount: number;

  @Column({ type: 'numeric', precision: 5, scale: 2, default: 0 })
  tax_rate: number;

  @Column({ type: 'numeric', precision: 18, scale: 2, default: 0 })
  tax_amount: number;

  @Column({ type: 'jsonb', nullable: true })
  ai_suggestion: any;

  @ManyToOne(() => APInvoiceEntity, invoice => invoice.lines)
  @JoinColumn({ name: 'invoice_id' })
  invoice: APInvoiceEntity;
}
