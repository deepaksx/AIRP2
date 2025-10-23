import { Entity, Column, PrimaryGeneratedColumn, ManyToOne, JoinColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  user_id: string;

  @Column('uuid')
  tenant_id: string;

  @Column({ length: 100, unique: true })
  username: string;

  @Column({ length: 255, unique: true })
  email: string;

  @Column({ length: 255 })
  full_name: string;

  @Column({ length: 255 })
  password_hash: string;

  @Column({ length: 50, nullable: true })
  employee_id: string;

  @Column({ length: 100, nullable: true })
  department: string;

  @Column({ length: 100, nullable: true })
  job_title: string;

  @Column({ length: 50, nullable: true })
  phone: string;

  @Column({ length: 20, default: 'active' })
  status: string;

  @Column({ default: false })
  is_system_user: boolean;

  @Column({ type: 'timestamptz', nullable: true })
  last_login_at: Date;

  @Column({ length: 45, nullable: true })
  last_login_ip: string;

  @Column({ type: 'timestamptz', nullable: true })
  password_changed_at: Date;

  @Column({ default: 0 })
  failed_login_attempts: number;

  @Column({ type: 'timestamptz', nullable: true })
  locked_until: Date;

  @Column({ type: 'jsonb', default: {} })
  preferences: any;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @Column({ type: 'uuid', nullable: true })
  created_by: string;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;

  @Column({ type: 'uuid', nullable: true })
  updated_by: string;

  // AI Context Fields
  @Column({ type: 'text', nullable: true })
  ai_context_summary: string;

  @Column({ type: 'text', array: true, nullable: true })
  ai_context_keywords: string[];

  @Column({ type: 'jsonb', nullable: true })
  ai_context_entities: any;

  @Column({ type: 'jsonb', nullable: true })
  ai_context_relationships: any;

  @Column({ type: 'timestamptz', nullable: true })
  ai_context_generated_at: Date;

  @Column({ length: 50, nullable: true })
  ai_context_model_version: string;

  @Column({ type: 'jsonb', default: {} })
  metadata: any;
}
