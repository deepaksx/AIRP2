import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { VendorEntity } from './vendor.entity';

@Injectable()
export class VendorsService {
  private readonly logger = new Logger(VendorsService.name);

  constructor(
    @InjectRepository(VendorEntity)
    private vendorRepo: Repository<VendorEntity>,
  ) {}

  async findAll(tenantId: string): Promise<VendorEntity[]> {
    return this.vendorRepo.find({
      where: { tenant_id: tenantId },
      order: { vendor_name: 'ASC' },
    });
  }

  async findOne(id: string, tenantId: string): Promise<VendorEntity> {
    return this.vendorRepo.findOne({
      where: { vendor_id: id, tenant_id: tenantId },
    });
  }

  async create(vendorData: Partial<VendorEntity>): Promise<VendorEntity> {
    const vendor = this.vendorRepo.create(vendorData);
    return this.vendorRepo.save(vendor);
  }

  async update(id: string, vendorData: Partial<VendorEntity>): Promise<VendorEntity> {
    await this.vendorRepo.update(id, vendorData);
    return this.vendorRepo.findOne({ where: { vendor_id: id } });
  }
}
