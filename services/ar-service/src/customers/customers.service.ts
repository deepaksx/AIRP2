import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CustomerEntity } from './customer.entity';

@Injectable()
export class CustomersService {
  private readonly logger = new Logger(CustomersService.name);

  constructor(
    @InjectRepository(CustomerEntity)
    private customerRepo: Repository<CustomerEntity>,
  ) {}

  async findAll(tenantId: string): Promise<CustomerEntity[]> {
    return this.customerRepo.find({
      where: { tenant_id: tenantId },
      order: { customer_name: 'ASC' },
    });
  }

  async findOne(id: string, tenantId: string): Promise<CustomerEntity> {
    return this.customerRepo.findOne({
      where: { customer_id: id, tenant_id: tenantId },
    });
  }

  async create(customerData: Partial<CustomerEntity>): Promise<CustomerEntity> {
    const customer = this.customerRepo.create(customerData);
    return this.customerRepo.save(customer);
  }
}
