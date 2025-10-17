import { Entity, Column, PrimaryGeneratedColumn, Index, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('approval_workflows')
@Index(['tenant_id'])
@Index(['entity_type', 'entity_id'])
export class ApprovalWorkflowEntity {
  @PrimaryGeneratedColumn('uuid')
  workflow_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'varchar', length: 50 })
  entity_type: string; // journal_entry, invoice, payment, budget

  @Column({ type: 'uuid' })
  entity_id: string;

  @Column({ type: 'integer', default: 1 })
  current_step: number;

  @Column({ type: 'integer', default: 1 })
  total_steps: number;

  @Column({ type: 'varchar', length: 20, default: 'pending' })
  status: string; // pending, approved, rejected

  @Column({ type: 'uuid', nullable: true })
  current_approver_id: string;

  @Column({ type: 'uuid', nullable: true })
  approved_by: string;

  @Column({ type: 'timestamptz', nullable: true })
  approved_at: Date;

  @Column({ type: 'text', nullable: true })
  rejection_reason: string;

  @Column({ type: 'jsonb', nullable: true })
  workflow_config: any;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
