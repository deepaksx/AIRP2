import { Injectable, Logger, Inject } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ClientProxy } from '@nestjs/microservices';
import { ARInvoiceEntity } from './ar-invoice.entity';
import { ARInvoiceLineEntity } from './ar-invoice-line.entity';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class InvoicesService {
  private readonly logger = new Logger(InvoicesService.name);

  constructor(
    @InjectRepository(ARInvoiceEntity)
    private invoiceRepo: Repository<ARInvoiceEntity>,
    @InjectRepository(ARInvoiceLineEntity)
    private lineRepo: Repository<ARInvoiceLineEntity>,
    @Inject('KAFKA_SERVICE')
    private readonly kafkaClient: ClientProxy,
  ) {}

  async findAll(tenantId: string): Promise<ARInvoiceEntity[]> {
    return this.invoiceRepo.find({
      where: { tenant_id: tenantId },
      relations: ['lines'],
      order: { invoice_date: 'DESC' },
    });
  }

  async findOne(id: string, tenantId: string): Promise<ARInvoiceEntity> {
    return this.invoiceRepo.findOne({
      where: { invoice_id: id, tenant_id: tenantId },
      relations: ['lines'],
    });
  }

  async create(invoiceData: Partial<ARInvoiceEntity>): Promise<ARInvoiceEntity> {
    const invoice = this.invoiceRepo.create(invoiceData);
    const savedInvoice = await this.invoiceRepo.save(invoice);

    // Publish event to Kafka for event sourcing
    try {
      const event = {
        event_id: uuidv4(),
        event_type: 'invoice-issued',
        timestamp: new Date().toISOString(),
        tenant_id: savedInvoice.tenant_id,
        invoice_id: savedInvoice.invoice_id,
        customer_id: savedInvoice.customer_id,
        invoice_number: savedInvoice.invoice_number,
        invoice_date: savedInvoice.invoice_date,
        due_date: savedInvoice.due_date,
        total_amount: parseFloat(savedInvoice.total_amount.toString()),
        amount_paid: parseFloat(savedInvoice.amount_paid?.toString() || '0'),
        amount_outstanding: parseFloat(savedInvoice.amount_outstanding?.toString() || savedInvoice.total_amount.toString()),
        currency: savedInvoice.currency,
        status: savedInvoice.status,
        lines: savedInvoice.lines || [],
      };

      this.kafkaClient.emit('airp.events.invoice-issued', event);
      this.logger.log(`Published invoice-issued event for invoice ${savedInvoice.invoice_id}`);
    } catch (error) {
      this.logger.error(`Failed to publish event for invoice ${savedInvoice.invoice_id}: ${error.message}`);
      // Don't fail the invoice creation if event publishing fails
    }

    return savedInvoice;
  }
}
