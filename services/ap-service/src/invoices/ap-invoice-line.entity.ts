import { Entity, Column, PrimaryGeneratedColumn, ManyToOne, JoinColumn } from 'typeorm';
import { APInvoiceEntity } from './ap-invoice.entity';

@Entity('ap_invoice_lines')
export class APInvoiceLineEntity {
  @PrimaryGeneratedColumn('uuid')
  line_id: string;

  @Column({ type: 'uuid' })
  invoice_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'integer' })
  line_number: number;

  @Column({ type: 'text' })
  description: string;

  @Column({ type: 'numeric', precision: 12, scale: 4, default: 1 })
  quantity: number;

  @Column({ type: 'numeric', precision: 20, scale: 4 })
  unit_price: number;

  @Column({ type: 'numeric', precision: 20, scale: 4 })
  line_amount: number;

  @Column({ type: 'numeric', precision: 5, scale: 4, default: 0.05 })
  tax_rate: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  tax_amount: number;

  @Column({ type: 'uuid', nullable: true })
  gl_account_id: string;

  @Column({ type: 'uuid', nullable: true })
  ai_suggested_account_id: string;

  @Column({ type: 'numeric', precision: 5, scale: 4, nullable: true })
  ai_confidence_score: number;

  @Column({ type: 'varchar', length: 50, nullable: true })
  dimension_1: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  dimension_2: string;

  @Column({ type: 'timestamptz', nullable: true })
  created_at: Date;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;

  @ManyToOne(() => APInvoiceEntity, invoice => invoice.lines)
  @JoinColumn({ name: 'invoice_id' })
  invoice: APInvoiceEntity;
}
