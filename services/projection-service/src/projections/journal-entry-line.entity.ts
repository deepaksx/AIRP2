import { Entity, Column, PrimaryColumn, CreateDateColumn } from 'typeorm';

@Entity('journal_entry_lines')
export class JournalEntryLineEntity {
  @PrimaryColumn('uuid')
  line_id: string;

  @Column({ type: 'uuid' })
  entry_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'int' })
  line_number: number;

  @Column({ type: 'uuid' })
  account_id: string;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  debit_amount: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  credit_amount: number;

  @Column({ type: 'char', length: 3, default: 'AED' })
  currency: string;

  @Column({ type: 'numeric', precision: 12, scale: 6, default: 1.0 })
  exchange_rate: number;

  @Column({ type: 'text', nullable: true })
  description: string;

  // Sub-ledger dimensions
  @Column({ type: 'varchar', length: 50, nullable: true })
  dimension_1: string; // vendor_id for AP

  @Column({ type: 'varchar', length: 50, nullable: true })
  dimension_2: string; // customer_id for AR

  @Column({ type: 'varchar', length: 50, nullable: true })
  dimension_3: string; // project_id

  @Column({ type: 'varchar', length: 50, nullable: true })
  dimension_4: string; // cost_center_id

  @CreateDateColumn()
  created_at: Date;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;
}
