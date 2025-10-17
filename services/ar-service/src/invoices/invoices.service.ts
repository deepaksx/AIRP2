import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ARInvoiceEntity } from './ar-invoice.entity';
import { ARInvoiceLineEntity } from './ar-invoice-line.entity';

@Injectable()
export class InvoicesService {
  private readonly logger = new Logger(InvoicesService.name);

  constructor(
    @InjectRepository(ARInvoiceEntity)
    private invoiceRepo: Repository<ARInvoiceEntity>,
    @InjectRepository(ARInvoiceLineEntity)
    private lineRepo: Repository<ARInvoiceLineEntity>,
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
    return this.invoiceRepo.save(invoice);
  }
}
