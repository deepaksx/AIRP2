import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('purchase_orders')
export class PurchaseOrder {
  @PrimaryGeneratedColumn('uuid')
  po_id: string;

  @Column('uuid')
  tenant_id: string;

  @Column({ length: 50 })
  po_number: string;

  @Column('date')
  po_date: Date;

  @Column('uuid')
  vendor_id: string;

  @Column('date', { nullable: true })
  requested_delivery_date: Date;

  @Column('uuid', { nullable: true })
  warehouse_id: string;

  @Column({ length: 3, default: 'AED' })
  currency: string;

  @Column('decimal', { precision: 15, scale: 4, default: 0 })
  subtotal: number;

  @Column('decimal', { precision: 15, scale: 4, default: 0 })
  tax_amount: number;

  @Column('decimal', { precision: 15, scale: 4, default: 0 })
  total_amount: number;

  @Column({ length: 50, default: 'DRAFT' })
  status: string;

  @Column({ length: 100, nullable: true })
  payment_terms: string;

  @Column({ length: 100, nullable: true })
  delivery_terms: string;

  @Column('uuid', { nullable: true })
  approved_by: string;

  @Column('timestamptz', { nullable: true })
  approved_at: Date;

  @Column('text', { nullable: true })
  notes: string;

  @CreateDateColumn()
  created_at: Date;

  @Column('uuid', { nullable: true })
  created_by: string;

  @UpdateDateColumn()
  updated_at: Date;

  @Column('uuid', { nullable: true })
  updated_by: string;

  @Column('jsonb', { default: {} })
  metadata: any;
}
