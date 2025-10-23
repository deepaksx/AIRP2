import { Entity, Column, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

@Entity('inventory_stock')
export class InventoryStock {
  @PrimaryGeneratedColumn('uuid')
  stock_id: string;

  @Column('uuid')
  tenant_id: string;

  @Column('uuid')
  item_id: string;

  @Column('uuid')
  warehouse_id: string;

  @Column('decimal', { precision: 15, scale: 4, default: 0 })
  quantity_on_hand: number;

  @Column('decimal', { precision: 15, scale: 4, default: 0 })
  quantity_reserved: number;

  @Column('decimal', { precision: 15, scale: 4, default: 0 })
  quantity_available: number;

  @Column('decimal', { precision: 15, scale: 4, default: 0 })
  quantity_on_order: number;

  @Column('decimal', { precision: 15, scale: 4, default: 0 })
  total_value: number;

  @Column('decimal', { precision: 15, scale: 4, default: 0 })
  average_cost: number;

  @Column('timestamptz', { nullable: true })
  last_receipt_date: Date;

  @Column('timestamptz', { nullable: true })
  last_issue_date: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
