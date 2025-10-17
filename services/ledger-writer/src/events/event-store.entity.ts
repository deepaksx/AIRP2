import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  Index,
  CreateDateColumn,
} from 'typeorm';

@Entity('event_store')
@Index(['tenant_id', 'timestamp'])
@Index(['aggregate_id'])
@Index(['event_type'])
@Index(['correlation_id'])
export class EventStoreEntity {
  @PrimaryGeneratedColumn('uuid')
  event_id: string;

  @Column({ type: 'uuid' })
  @Index()
  tenant_id: string;

  @Column({ type: 'uuid' })
  @Index()
  aggregate_id: string;

  @Column({ type: 'varchar', length: 50 })
  aggregate_type: string;

  @Column({ type: 'varchar', length: 100 })
  event_type: string;

  @Column({ type: 'integer', default: 1 })
  event_version: number;

  @Column({ type: 'jsonb' })
  event_data: any;

  @Column({ type: 'jsonb', nullable: true })
  event_metadata: any;

  @Column({ type: 'uuid', nullable: true })
  causation_id: string;

  @Column({ type: 'uuid', nullable: true })
  correlation_id: string;

  @Column({ type: 'uuid', nullable: true })
  user_id: string;

  @CreateDateColumn({ type: 'timestamptz' })
  timestamp: Date;

  @Column({ type: 'bigint', nullable: true })
  sequence_number: number;

  @Column({ type: 'varchar', length: 64, nullable: true })
  checksum: string;
}
