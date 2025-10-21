# AI Context Integration Guide

## Adding Real-Time Context Generation to Your Services

This guide shows how to integrate automatic AI context generation into existing AIRP services.

---

## **1. Install Shared Context Client**

```bash
# In your service directory (e.g., services/ledger-writer)
npm install axios
```

Then copy `services/shared/context-client.ts` to your service or import it.

---

## **2. Configure Environment Variables**

Add to your service's `.env` or `docker-compose.yml`:

```env
CONTEXT_SERVICE_URL=http://ai-context-generator:8007
CONTEXT_GENERATION_ENABLED=true
```

---

## **3. Integration Examples**

### **A. Ledger Writer Service - Journal Entries**

**File**: `services/ledger-writer/src/journal-entries/journal-entries.service.ts`

```typescript
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JournalEntry } from './entities/journal-entry.entity';
import { JournalEntryLine } from './entities/journal-entry-line.entity';
import { generateJournalEntryContext } from '../../shared/context-client';

@Injectable()
export class JournalEntriesService {
  constructor(
    @InjectRepository(JournalEntry)
    private journalEntryRepository: Repository<JournalEntry>,
    @InjectRepository(JournalEntryLine)
    private journalEntryLineRepository: Repository<JournalEntryLine>,
  ) {}

  async create(createJournalEntryDto: CreateJournalEntryDto) {
    // 1. Create journal entry (existing logic)
    const entry = this.journalEntryRepository.create(createJournalEntryDto);
    const savedEntry = await this.journalEntryRepository.save(entry);

    // 2. Create journal entry lines (existing logic)
    const lines = createJournalEntryDto.lines.map(line =>
      this.journalEntryLineRepository.create({
        ...line,
        entry_id: savedEntry.entry_id,
        tenant_id: savedEntry.tenant_id,
      })
    );
    const savedLines = await this.journalEntryLineRepository.save(lines);

    // 3. 🆕 GENERATE AI CONTEXT (async, non-blocking)
    await generateJournalEntryContext(savedEntry, savedLines);

    return { ...savedEntry, lines: savedLines };
  }

  async update(id: string, updateJournalEntryDto: UpdateJournalEntryDto) {
    // 1. Update journal entry (existing logic)
    await this.journalEntryRepository.update(id, updateJournalEntryDto);
    const updatedEntry = await this.journalEntryRepository.findOne({
      where: { entry_id: id },
      relations: ['lines']
    });

    // 2. 🆕 REGENERATE CONTEXT (if description or lines changed)
    if (updateJournalEntryDto.description || updateJournalEntryDto.lines) {
      await generateJournalEntryContext(updatedEntry, updatedEntry.lines);
    }

    return updatedEntry;
  }
}
```

---

### **B. AP Service - Vendors**

**File**: `services/ap-service/src/vendors/vendors.service.ts`

```typescript
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Vendor } from './entities/vendor.entity';
import { generateVendorContext } from '../../shared/context-client';

@Injectable()
export class VendorsService {
  constructor(
    @InjectRepository(Vendor)
    private vendorRepository: Repository<Vendor>,
  ) {}

  async create(createVendorDto: CreateVendorDto) {
    // 1. Create vendor (existing logic)
    const vendor = this.vendorRepository.create(createVendorDto);
    const savedVendor = await this.vendorRepository.save(vendor);

    // 2. 🆕 GENERATE AI CONTEXT
    await generateVendorContext(savedVendor);

    return savedVendor;
  }

  async update(id: string, updateVendorDto: UpdateVendorDto) {
    // 1. Update vendor (existing logic)
    await this.vendorRepository.update(id, updateVendorDto);
    const updatedVendor = await this.vendorRepository.findOne({
      where: { vendor_id: id }
    });

    // 2. 🆕 REGENERATE CONTEXT (if name or key fields changed)
    if (updateVendorDto.vendor_name || updateVendorDto.payment_terms) {
      await generateVendorContext(updatedVendor);
    }

    return updatedVendor;
  }
}
```

---

### **C. AP Service - AP Invoices**

**File**: `services/ap-service/src/invoices/invoices.service.ts`

```typescript
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { APInvoice } from './entities/ap-invoice.entity';
import { generateAPInvoiceContext } from '../../shared/context-client';

@Injectable()
export class InvoicesService {
  constructor(
    @InjectRepository(APInvoice)
    private invoiceRepository: Repository<APInvoice>,
  ) {}

  async create(createInvoiceDto: CreateInvoiceDto) {
    // 1. Create invoice (existing logic)
    const invoice = this.invoiceRepository.create(createInvoiceDto);
    const savedInvoice = await this.invoiceRepository.save(invoice);

    // 2. 🆕 GENERATE AI CONTEXT
    await generateAPInvoiceContext(savedInvoice);

    return savedInvoice;
  }

  async approve(id: string, userId: string) {
    // 1. Approve invoice (existing logic)
    await this.invoiceRepository.update(id, {
      approval_status: 'approved',
      approved_by: userId,
      approved_at: new Date(),
    });
    const approvedInvoice = await this.invoiceRepository.findOne({
      where: { invoice_id: id }
    });

    // 2. 🆕 REGENERATE CONTEXT (status changed to approved)
    await generateAPInvoiceContext(approvedInvoice);

    return approvedInvoice;
  }
}
```

---

### **D. AR Service - Customers**

**File**: `services/ar-service/src/customers/customers.service.ts`

```typescript
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Customer } from './entities/customer.entity';
import { generateCustomerContext } from '../../shared/context-client';

@Injectable()
export class CustomersService {
  constructor(
    @InjectRepository(Customer)
    private customerRepository: Repository<Customer>,
  ) {}

  async create(createCustomerDto: CreateCustomerDto) {
    const customer = this.customerRepository.create(createCustomerDto);
    const savedCustomer = await this.customerRepository.save(customer);

    // 🆕 GENERATE AI CONTEXT
    await generateCustomerContext(savedCustomer);

    return savedCustomer;
  }

  async update(id: string, updateCustomerDto: UpdateCustomerDto) {
    await this.customerRepository.update(id, updateCustomerDto);
    const updatedCustomer = await this.customerRepository.findOne({
      where: { customer_id: id }
    });

    // 🆕 REGENERATE CONTEXT
    if (updateCustomerDto.customer_name || updateCustomerDto.payment_terms) {
      await generateCustomerContext(updatedCustomer);
    }

    return updatedCustomer;
  }
}
```

---

### **E. AR Service - AR Invoices**

**File**: `services/ar-service/src/invoices/invoices.service.ts`

```typescript
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ARInvoice } from './entities/ar-invoice.entity';
import { generateARInvoiceContext } from '../../shared/context-client';

@Injectable()
export class InvoicesService {
  constructor(
    @InjectRepository(ARInvoice)
    private invoiceRepository: Repository<ARInvoice>,
  ) {}

  async create(createInvoiceDto: CreateInvoiceDto) {
    const invoice = this.invoiceRepository.create(createInvoiceDto);
    const savedInvoice = await this.invoiceRepository.save(invoice);

    // 🆕 GENERATE AI CONTEXT
    await generateARInvoiceContext(savedInvoice);

    return savedInvoice;
  }
}
```

---

## **4. Error Handling**

The context client is designed to be **non-blocking**:

```typescript
// Context generation runs in background
await generateVendorContext(vendor);
// ☝️ This returns immediately (fire-and-forget)
// If it fails, it logs error but doesn't throw

// Main operation continues successfully
return vendor;
```

**Why Non-Blocking?**
- Context generation takes 2-3 seconds (Claude API call)
- We don't want to slow down user operations
- Context failure shouldn't break vendor creation
- Context can be regenerated later if needed

---

## **5. Monitoring Context Generation**

### **Check Service Health**

```typescript
import { contextService } from './shared/context-client';

// In your app startup
const isHealthy = await contextService.healthCheck();
if (!isHealthy) {
  console.warn('⚠️ AI Context service unavailable - context generation disabled');
}
```

### **Check Coverage**

```bash
# Get context coverage statistics
curl "http://localhost:8007/context-stats?tenant_id=00000000-0000-0000-0000-000000000001"
```

### **View Logs**

```bash
# Context service logs
docker logs -f airp-ai-context-generator

# Your service logs (will show context generation messages)
docker logs -f airp-ledger-writer
```

---

## **6. Configuration Options**

### **Environment Variables**

| Variable | Default | Description |
|----------|---------|-------------|
| `CONTEXT_SERVICE_URL` | `http://localhost:8007` | AI Context Generator URL |
| `CONTEXT_GENERATION_ENABLED` | `true` | Enable/disable context generation |

### **Disable Context Generation**

```env
# In development, you can disable context generation
CONTEXT_GENERATION_ENABLED=false
```

---

## **7. Testing Integration**

### **Test Context Generation**

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { VendorsService } from './vendors.service';
import { contextService } from './shared/context-client';

describe('VendorsService', () => {
  let service: VendorsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [VendorsService],
    }).compile();

    service = module.get<VendorsService>(VendorsService);
  });

  it('should generate context when creating vendor', async () => {
    const vendor = await service.create({
      vendor_name: 'Test Vendor LLC',
      tenant_id: 'test-tenant',
      payment_terms: 30,
    });

    // Wait a bit for async context generation
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Check if context was generated
    const stats = await contextService.getStats('test-tenant');
    expect(stats.by_entity_type.vendors.records_with_context).toBeGreaterThan(0);
  });
});
```

---

## **8. Rollout Strategy**

### **Phase 1: Enable for New Records Only**
- Add context generation to `create()` methods
- Existing records: use batch generation script

### **Phase 2: Enable for Updates**
- Add context regeneration to `update()` methods
- Only regenerate when key fields change

### **Phase 3: Periodic Refresh**
- Cron job to refresh stale context (>30 days old)
- Updates context based on transaction history

---

## **9. Troubleshooting**

### **Context Not Generating**

```bash
# Check if service is running
docker ps | grep context-generator

# Check logs
docker logs airp-ai-context-generator

# Test manually
curl -X POST http://localhost:8007/generate-context \
  -H "Content-Type: application/json" \
  -d '{"entity_type":"vendor","entity_id":"test","tenant_id":"test","entity_data":{}}'
```

### **Slow Performance**

```typescript
// Context generation is async by default
// If you're seeing slow responses, check if you're using blocking version:

// ❌ BLOCKING (slow)
await contextService.generateContext(request);

// ✅ NON-BLOCKING (fast)
await contextService.generateContextAsync(request);
```

### **Missing API Key**

```bash
# Check if ANTHROPIC_API_KEY is set
docker exec airp-ai-context-generator env | grep ANTHROPIC

# Set it
export ANTHROPIC_API_KEY=sk-ant-...
docker compose restart ai-context-generator
```

---

## **10. Complete Example: Full Service Integration**

**File**: `services/ledger-writer/src/main.ts`

```typescript
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { contextService } from './shared/context-client';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Check context service health on startup
  const isContextHealthy = await contextService.healthCheck();
  if (isContextHealthy) {
    console.log('✅ AI Context service is healthy');
  } else {
    console.warn('⚠️ AI Context service unavailable - context generation will be skipped');
  }

  await app.listen(3001);
  console.log('🚀 Ledger Writer running on port 3001');
}

bootstrap();
```

---

## **Summary**

1. ✅ Copy `context-client.ts` to your service
2. ✅ Add `await generateXxxContext(record)` after save operations
3. ✅ Use `generateContextAsync()` for non-blocking execution
4. ✅ Context failures won't break your main operations
5. ✅ Monitor coverage with `/context-stats` endpoint

**That's it!** Your service now automatically generates intelligent context for all new records. 🎉
