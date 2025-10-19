import { Entity, Column, PrimaryGeneratedColumn, Index, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('chart_of_accounts')
@Index(['tenant_id', 'account_code'], { unique: true })
export class ChartOfAccountsEntity {
  @PrimaryGeneratedColumn('uuid')
  account_id: string;

  @Column({ type: 'uuid' })
  @Index()
  tenant_id: string;

  @Column({ type: 'varchar', length: 50 })
  account_code: string;

  @Column({ type: 'varchar', length: 255 })
  account_name: string;

  @Column({ type: 'varchar', length: 50 })
  account_type: string; // asset, liability, equity, revenue, expense

  @Column({ type: 'varchar', length: 50, nullable: true })
  account_subtype: string;

  @Column({ type: 'uuid', nullable: true })
  parent_account_id: string;

  @Column({ type: 'varchar', length: 10 })
  normal_balance: string; // debit or credit

  @Column({ type: 'boolean', default: false })
  is_control_account: boolean;

  @Column({ type: 'boolean', default: true })
  is_leaf: boolean;

  @Column({ type: 'char', length: 3, default: 'AED' })
  currency: string;

  @Column({ type: 'varchar', length: 20, default: 'active' })
  status: string; // active, inactive, archived

  @Column({ type: 'varchar', length: 100, nullable: true })
  ifrs_category: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  gaap_category: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  tax_category: string;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;
}
