import { Injectable, Logger, Inject } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ClientProxy } from '@nestjs/microservices';
import { APInvoiceEntity } from './ap-invoice.entity';
import { APInvoiceLineEntity } from './ap-invoice-line.entity';
import axios from 'axios';

@Injectable()
export class InvoicesService {
  private readonly logger = new Logger(InvoicesService.name);

  constructor(
    @InjectRepository(APInvoiceEntity)
    private invoiceRepo: Repository<APInvoiceEntity>,
    @InjectRepository(APInvoiceLineEntity)
    private lineRepo: Repository<APInvoiceLineEntity>,
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
    return this.invoiceRepo.save(invoice);
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
