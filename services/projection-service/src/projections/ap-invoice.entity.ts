import { Entity, Column, PrimaryColumn } from 'typeorm';

@Entity('ap_invoices')
export class APInvoiceEntity {
  @PrimaryColumn('uuid')
  invoice_id: string;

  @Column({ type: 'uuid' })
  tenant_id: string;

  @Column({ type: 'uuid' })
  vendor_id: string;

  @Column({ type: 'varchar', length: 100 })
  invoice_number: string;

  @Column({ type: 'date' })
  invoice_date: Date;

  @Column({ type: 'date' })
  due_date: Date;

  @Column({ type: 'char', length: 3, default: 'AED' })
  currency: string;

  @Column({ type: 'numeric', precision: 20, scale: 4 })
  total_amount: number;

  @Column({ type: 'numeric', precision: 20, scale: 4, default: 0 })
  amount_paid: number;

  @Column({ type: 'numeric', precision: 20, scale: 4 })
  amount_outstanding: number;

  @Column({ type: 'varchar', length: 20, default: 'unpaid' })
  payment_status: string;
}
