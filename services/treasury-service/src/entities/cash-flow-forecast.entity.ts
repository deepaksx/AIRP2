import { Entity, Column, PrimaryGeneratedColumn, Index } from 'typeorm';

@Entity('cash_flow_forecast')
@Index(['tenant_id', 'forecast_date'])
export class CashFlowForecastEntity {
  @PrimaryGeneratedColumn('uuid')
  forecast_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'date' })
  forecast_date: Date;

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  opening_balance: number;

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  expected_inflows: number;

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  expected_outflows: number;

  @Column({ type: 'numeric', precision: 18, scale: 2 })
  closing_balance: number;

  @Column({ type: 'varchar', length: 3, default: 'AED' })
  currency_code: string;

  @Column({ type: 'varchar', length: 20, default: 'ai' })
  forecast_method: string; // ai, manual, rule-based

  @Column({ type: 'numeric', precision: 5, scale: 2, nullable: true })
  confidence_score: number;

  @Column({ type: 'jsonb', nullable: true })
  metadata: any;

  @Column({ type: 'timestamptz' })
  created_at: Date;
}
