import { Entity, Column, PrimaryGeneratedColumn, Index, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('bank_accounts')
@Index(['tenant_id'])
export class BankAccountEntity {
  @PrimaryGeneratedColumn('uuid')
  account_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'varchar', length: 100 })
  bank_name: string;

  @Column({ type: 'varchar', length: 50 })
  account_number: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  iban: string;

  @Column({ type: 'varchar', length: 20, nullable: true })
  swift_code: string;

  @Column({ type: 'varchar', length: 3, default: 'AED' })
  currency_code: string;

  @Column({ type: 'numeric', precision: 18, scale: 2, default: 0 })
  current_balance: number;

  @Column({ type: 'varchar', length: 20, default: 'active' })
  status: string;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
