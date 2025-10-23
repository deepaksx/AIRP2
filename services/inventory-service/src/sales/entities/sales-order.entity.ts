import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('sales_orders')
export class SalesOrder {
  @PrimaryGeneratedColumn('uuid')
  so_id: string;

  @Column('uuid')
  tenant_id: string;

  @Column({ length: 50 })
  so_number: string;

  @Column('date')
  so_date: Date;

  @Column('uuid')
  customer_id: string;

  @Column('date', { nullable: true })
  requested_delivery_date: Date;

  @Column('uuid', { nullable: true })
  warehouse_id: string;

  @Column({ length: 255, nullable: true })
  ship_to_name: string;

  @Column('text', { nullable: true })
  ship_to_address: string;

  @Column({ length: 100, nullable: true })
  ship_to_city: string;

  @Column({ length: 100, nullable: true })
  ship_to_country: string;

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

  // COPA Characteristics
  @Column({ length: 50, nullable: true })
  copa_sales_org: string;

  @Column({ length: 50, nullable: true })
  copa_distribution_channel: string;

  @Column({ length: 50, nullable: true })
  copa_division: string;

  @Column({ length: 50, nullable: true })
  copa_sales_office: string;

  @Column({ length: 50, nullable: true })
  copa_sales_group: string;

  @Column({ length: 50, nullable: true })
  copa_region: string;

  @Column({ length: 50, nullable: true })
  copa_country: string;

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
