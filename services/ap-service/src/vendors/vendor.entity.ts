import { Entity, Column, PrimaryGeneratedColumn, Index, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('vendors')
@Index(['tenant_id'])
export class VendorEntity {
  @PrimaryGeneratedColumn('uuid')
  vendor_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'varchar', length: 50, unique: true })
  vendor_code: string;

  @Column({ type: 'varchar', length: 200 })
  vendor_name: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  contact_person: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  email: string;

  @Column({ type: 'varchar', length: 20, nullable: true })
  phone: string;

  @Column({ type: 'text', nullable: true })
  address: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  tax_id: string;

  @Column({ type: 'varchar', length: 3, default: 'AED' })
  default_currency: string;

  @Column({ type: 'integer', default: 30 })
  payment_terms_days: number;

  @Column({ type: 'varchar', length: 20, default: 'active' })
  status: string;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
