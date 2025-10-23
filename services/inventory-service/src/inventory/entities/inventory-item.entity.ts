import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('inventory_items')
export class InventoryItem {
  @PrimaryGeneratedColumn('uuid')
  item_id: string;

  @Column('uuid')
  tenant_id: string;

  @Column({ length: 50 })
  item_code: string;

  @Column({ length: 255 })
  item_name: string;

  @Column('text', { nullable: true })
  description: string;

  @Column({ length: 50, default: 'FINISHED_GOODS' })
  item_type: string;

  @Column({ length: 100, nullable: true })
  item_category: string;

  @Column({ length: 100, nullable: true })
  product_group: string;

  @Column({ length: 20, default: 'EA' })
  base_unit: string;

  @Column({ length: 50, default: 'WEIGHTED_AVERAGE' })
  valuation_method: string;

  @Column('decimal', { precision: 15, scale: 4, default: 0 })
  standard_cost: number;

  @Column('uuid', { nullable: true })
  inventory_account_id: string;

  @Column('uuid', { nullable: true })
  cogs_account_id: string;

  @Column('uuid', { nullable: true })
  revenue_account_id: string;

  @Column('uuid', { nullable: true })
  inventory_variance_account_id: string;

  @Column({ default: true })
  is_active: boolean;

  @Column({ default: true })
  is_stockable: boolean;

  @Column({ default: true })
  is_purchasable: boolean;

  @Column({ default: true })
  is_saleable: boolean;

  @Column('text', { nullable: true })
  ai_context_summary: string;

  @Column('text', { array: true, nullable: true })
  ai_context_keywords: string[];

  @Column('timestamptz', { nullable: true })
  ai_context_generated_at: Date;

  @Column({ default: false })
  ai_needs_context_update: boolean;

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
