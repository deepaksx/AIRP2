import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('warehouses')
export class Warehouse {
  @PrimaryGeneratedColumn('uuid')
  warehouse_id: string;

  @Column('uuid')
  tenant_id: string;

  @Column({ length: 50 })
  warehouse_code: string;

  @Column({ length: 255 })
  warehouse_name: string;

  @Column({ length: 50, default: 'STANDARD' })
  warehouse_type: string;

  @Column({ length: 255, nullable: true })
  address_line1: string;

  @Column({ length: 255, nullable: true })
  address_line2: string;

  @Column({ length: 100, nullable: true })
  city: string;

  @Column({ length: 100, nullable: true })
  state: string;

  @Column({ length: 20, nullable: true })
  postal_code: string;

  @Column({ length: 100, nullable: true })
  country: string;

  @Column({ length: 255, nullable: true })
  contact_person: string;

  @Column({ length: 50, nullable: true })
  phone: string;

  @Column({ length: 255, nullable: true })
  email: string;

  @Column({ default: true })
  is_active: boolean;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;

  @Column('jsonb', { default: {} })
  metadata: any;
}
