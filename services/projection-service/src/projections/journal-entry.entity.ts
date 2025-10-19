import { Entity, Column, PrimaryColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('journal_entries')
export class JournalEntryEntity {
  @PrimaryColumn('uuid')
  entry_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'varchar', length: 50 })
  entry_number: string;

  @Column({ type: 'date' })
  entry_date: Date;

  @Column({ type: 'date' })
  posting_date: Date;

  @Column({ type: 'varchar', length: 50 })
  entry_type: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  source_type: string;

  @Column({ type: 'varchar', length: 255, nullable: true })
  source_ref_id: string;

  @Column({ type: 'text' })
  description: string;

  @Column({ type: 'char', length: 3, default: 'AED' })
  currency: string;

  @Column({ type: 'numeric', precision: 20, scale: 4 })
  total_debit: number;

  @Column({ type: 'numeric', precision: 20, scale: 4 })
  total_credit: number;

  @Column({ type: 'varchar', length: 20, default: 'draft' })
  status: string;

  @Column({ type: 'uuid', nullable: true })
  approved_by: string;

  @Column({ type: 'timestamp with time zone', nullable: true })
  approved_at: Date;

  @Column({ type: 'uuid', nullable: true })
  posted_by: string;

  @Column({ type: 'timestamp with time zone', nullable: true })
  posted_at: Date;

  @Column({ type: 'uuid', nullable: true })
  reversed_by: string;

  @Column({ type: 'timestamp with time zone', nullable: true })
  reversed_at: Date;

  @Column({ type: 'uuid', nullable: true })
  reversal_entry_id: string;

  @Column({ type: 'numeric', precision: 5, scale: 4, nullable: true })
  ai_confidence_score: number;

  @Column({ type: 'varchar', length: 50, nullable: true })
  ai_model_version: string;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;
}
