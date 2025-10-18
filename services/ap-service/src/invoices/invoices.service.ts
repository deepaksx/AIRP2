import { Injectable, Logger, Inject } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ClientProxy } from '@nestjs/microservices';
import { APInvoiceEntity } from './ap-invoice.entity';
import { APInvoiceLineEntity } from './ap-invoice-line.entity';
import axios from 'axios';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class InvoicesService {
  private readonly logger = new Logger(InvoicesService.name);

  constructor(
    @InjectRepository(APInvoiceEntity)
    private invoiceRepo: Repository<APInvoiceEntity>,
    @InjectRepository(APInvoiceLineEntity)
    private lineRepo: Repository<APInvoiceLineEntity>,
    @Inject('KAFKA_SERVICE')
    private readonly kafkaClient: ClientProxy,
  ) {}

  async findAll(tenantId: string): Promise<APInvoiceEntity[]> {
    return this.invoiceRepo.find({
      where: { tenant_id: tenantId },
      relations: ['lines'],
      order: { invoice_date: 'DESC' },
    });
  }

  async findOne(id: string, tenantId: string): Promise<APInvoiceEntity> {
    return this.invoiceRepo.findOne({
      where: { invoice_id: id, tenant_id: tenantId },
      relations: ['lines'],
    });
  }

  async create(invoiceData: Partial<APInvoiceEntity>): Promise<APInvoiceEntity> {
    const invoice = this.invoiceRepo.create(invoiceData);
    const savedInvoice = await this.invoiceRepo.save(invoice);

    // Publish event to Kafka for event sourcing
    try {
      const event = {
        event_id: uuidv4(),
        event_type: 'invoice-received',
        timestamp: new Date().toISOString(),
        tenant_id: savedInvoice.tenant_id,
        invoice_id: savedInvoice.invoice_id,
        vendor_id: savedInvoice.vendor_id,
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

      this.kafkaClient.emit('airp.events.invoice-received', event);
      this.logger.log(`Published invoice-received event for invoice ${savedInvoice.invoice_id}`);
    } catch (error) {
      this.logger.error(`Failed to publish event for invoice ${savedInvoice.invoice_id}: ${error.message}`);
      // Don't fail the invoice creation if event publishing fails
    }

    return savedInvoice;
  }

  async classifyWithAI(invoiceId: string, tenantId: string): Promise<any> {
    const invoice = await this.findOne(invoiceId, tenantId);

    if (!invoice) {
      throw new Error(`Invoice ${invoiceId} not found`);
    }

    try {
      const aiServiceUrl = process.env.AI_AUTO_ACCOUNTING_URL || 'http://localhost:8001';

      const response = await axios.post(`${aiServiceUrl}/classify`, {
        tenant_id: tenantId,
        invoice_id: invoiceId,
        transaction_type: 'AP',
        lines: invoice.lines.map(line => ({
          line_number: line.line_number,
          description: line.description,
          amount: parseFloat(line.line_amount.toString()),
          quantity: parseFloat(line.quantity.toString()),
        })),
      });

      this.logger.log(`AI classification completed for invoice ${invoiceId}`);

      // Update invoice with AI classifications
      await this.invoiceRepo.update(invoiceId, { ai_classified: true });

      return response.data;
    } catch (error) {
      this.logger.error(`AI classification failed: ${error.message}`);
      throw error;
    }
  }
}
