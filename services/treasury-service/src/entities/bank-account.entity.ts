import { Entity, Column, PrimaryGeneratedColumn, Index, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('bank_accounts')
@Index(['tenant_id'])
export class BankAccountEntity {
  @PrimaryGeneratedColumn('uuid')
  bank_account_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'varchar', length: 50 })
  account_code: string;

  @Column({ type: 'varchar', length: 255 })
  account_name: string;

  @Column({ type: 'varchar', length: 255 })
  bank_name: string;

  @Column({ type: 'varchar', length: 50 })
  account_number: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  iban: string;

  @Column({ type: 'varchar', length: 20, nullable: true })
  swift_code: string;

  @Column({ type: 'char', length: 3, default: 'AED' })
  currency: string;

  @Column({ type: 'varchar', length: 50, default: 'checking' })
  account_type: string;

  @Column({ type: 'uuid', nullable: true })
  gl_account_id: string;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  current_balance: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  available_balance: number;

  @Column({ type: 'varchar', length: 20, default: 'active' })
  status: string;

  @Column({ type: 'date', nullable: true })
  last_reconciled_date: Date;

  @Column({ type: 'numeric', precision: 20, scale: 4, nullable: true })
  last_reconciled_balance: number;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
