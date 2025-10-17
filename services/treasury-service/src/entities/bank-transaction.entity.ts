import { Entity, Column, PrimaryGeneratedColumn, Index, CreateDateColumn } from 'typeorm';

@Entity('bank_transactions')
@Index(['tenant_id'])
@Index(['account_id'])
export class BankTransactionEntity {
  @PrimaryGeneratedColumn('uuid')
  transaction_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'uuid' })
  account_id: string;

  @Column({ type: 'date' })
  transaction_date: Date;

  @Column({ type: 'varchar', length: 200 })
  description: string;

  @Column({ type: 'varchar', length: 20 })
  transaction_type: string; // debit, credit

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  amount: number;

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  balance_after: number;

  @Column({ type: 'varchar', length: 100, nullable: true })
  reference_number: string;

  @Column({ type: 'boolean', default: false })
  reconciled: boolean;

  @Column({ type: 'uuid', nullable: true })
  matched_transaction_id: string;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;
}
