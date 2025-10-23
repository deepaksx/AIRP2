import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('roles')
export class Role {
  @PrimaryGeneratedColumn('uuid')
  role_id: string;

  @Column('uuid')
  tenant_id: string;

  @Column({ length: 50 })
  role_code: string;

  @Column({ length: 100 })
  role_name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({ default: false })
  is_system_role: boolean;

  @Column({ default: true })
  is_active: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @Column({ type: 'uuid', nullable: true })
  created_by: string;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;

  @Column({ type: 'uuid', nullable: true })
  updated_by: string;

  @Column({ type: 'jsonb', default: {} })
  metadata: any;
}
