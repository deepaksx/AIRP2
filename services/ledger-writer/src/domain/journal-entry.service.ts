import { Injectable, Logger } from '@nestjs/common';
import { EventStoreService } from '../events/event-store.service';
import { v4 as uuidv4 } from 'uuid';
import { journalEntryCounter } from '../health/metrics.controller';

export interface CreateJournalEntryDto {
  tenantId: string;
  entryDate: string;
  entryType: string;
  description: string;
  lines: JournalEntryLineDto[];
  userId?: string;
  sourceType?: string;
  sourceRefId?: string;
  aiGenerated?: boolean;
  aiConfidenceScore?: number;
}

export interface JournalEntryLineDto {
  accountCode: string;
  debitAmount: number;
  creditAmount: number;
  description?: string;
  // Sub-ledger dimensions
  vendorId?: string;      // For AP transactions (account 2100)
  customerId?: string;    // For AR transactions (account 1200)
  projectId?: string;     // For project costing
  costCenterId?: string;  // For department/location tracking
  // Metadata
  invoiceNumber?: string;
  dueDate?: string;
  paymentTerms?: string;
  metadata?: any;         // Flexible JSONB storage
}

@Injectable()
export class JournalEntryService {
  private readonly logger = new Logger(JournalEntryService.name);

  constructor(private readonly eventStoreService: EventStoreService) {}

  async createJournalEntry(dto: CreateJournalEntryDto): Promise<any> {
    // Validate balanced entry
    const totalDebits = dto.lines.reduce((sum, line) => sum + line.debitAmount, 0);
    const totalCredits = dto.lines.reduce((sum, line) => sum + line.creditAmount, 0);

    if (Math.abs(totalDebits - totalCredits) > 0.01) {
      throw new Error(`Journal entry is not balanced. Debits: ${totalDebits}, Credits: ${totalCredits}`);
    }

    // ACCOUNTING CONTROL: Validate AR/AP control accounts have required dimensions
    for (const line of dto.lines) {
      // Check AR control account (1200) - MUST have customer
      if (line.accountCode === '1200') {
        if (!line.customerId) {
          throw new Error(
            `Account 1200 (Accounts Receivable) requires a Customer ID. ` +
            `Direct posting to AR control account is not allowed. ` +
            `Please select a customer or use AR invoice entry.`
          );
        }
      }

      // Check AP control account (2100) - MUST have vendor
      if (line.accountCode === '2100') {
        if (!line.vendorId) {
          throw new Error(
            `Account 2100 (Accounts Payable) requires a Vendor ID. ` +
            `Direct posting to AP control account is not allowed. ` +
            `Please select a vendor or use AP invoice entry.`
          );
        }
      }
    }

    const entryId = uuidv4();
    const correlationId = uuidv4();

    // Create journal entry event
    const event = await this.eventStoreService.appendEvent({
      tenantId: dto.tenantId,
      aggregateId: entryId,
      aggregateType: 'JournalEntry',
      eventType: 'JournalEntryPosted',
      eventData: {
        entryNumber: `JE-${Date.now()}`,
        entryDate: dto.entryDate,
        postingDate: dto.entryDate,
        entryType: dto.entryType,
        sourceType: dto.sourceType || 'Manual',
        description: dto.description,
        currency: 'AED',
        totalDebit: totalDebits.toFixed(4),
        totalCredit: totalCredits.toFixed(4),
        lines: dto.lines.map((line, index) => ({
          lineNumber: index + 1,
          accountCode: line.accountCode,
          debitAmount: line.debitAmount.toFixed(4),
          creditAmount: line.creditAmount.toFixed(4),
          description: line.description || dto.description,
          // Sub-ledger tracking
          vendorId: line.vendorId,
          customerId: line.customerId,
          projectId: line.projectId,
          costCenterId: line.costCenterId,
          // Additional metadata
          invoiceNumber: line.invoiceNumber,
          dueDate: line.dueDate,
          paymentTerms: line.paymentTerms,
          metadata: line.metadata,
        })),
        aiGenerated: dto.aiGenerated || false,
        aiConfidenceScore: dto.aiConfidenceScore?.toFixed(4),
      },
      correlationId,
      userId: dto.userId,
    });

    // Update metrics
    journalEntryCounter.inc({
      entry_type: dto.entryType,
      tenant_id: dto.tenantId,
    });

    this.logger.log(`Journal entry created: ${entryId} for tenant ${dto.tenantId}`);

    return {
      entryId,
      correlationId,
      event,
      status: 'posted',
    };
  }

  async reverseJournalEntry(
    entryId: string,
    tenantId: string,
    userId: string,
    reason: string,
  ): Promise<any> {
    // Get original journal entry events
    const originalEvents = await this.eventStoreService.getEventsByAggregate(entryId, tenantId);

    if (originalEvents.length === 0) {
      throw new Error(`Journal entry ${entryId} not found`);
    }

    const originalEntry = originalEvents.find((e) => e.event_type === 'JournalEntryPosted');

    if (!originalEntry) {
      throw new Error(`Original journal entry event not found for ${entryId}`);
    }

    const originalData = originalEntry.event_data;

    // Create reversing entry (swap debits and credits, preserve sub-ledger info)
    const reversedLines = originalData.lines.map((line) => ({
      accountCode: line.accountCode,
      debitAmount: parseFloat(line.creditAmount),
      creditAmount: parseFloat(line.debitAmount),
      description: `REVERSAL: ${line.description}`,
      // Preserve sub-ledger tracking
      vendorId: line.vendorId,
      customerId: line.customerId,
      projectId: line.projectId,
      costCenterId: line.costCenterId,
      invoiceNumber: line.invoiceNumber,
      metadata: line.metadata,
    }));

    const reversalEntryId = uuidv4();

    const event = await this.eventStoreService.appendEvent({
      tenantId,
      aggregateId: reversalEntryId,
      aggregateType: 'JournalEntry',
      eventType: 'JournalEntryPosted',
      eventData: {
        entryNumber: `REV-${originalData.entryNumber}`,
        entryDate: new Date().toISOString().split('T')[0],
        postingDate: new Date().toISOString().split('T')[0],
        entryType: 'Reversing',
        sourceType: 'Manual',
        description: `REVERSAL: ${originalData.description} - Reason: ${reason}`,
        currency: originalData.currency,
        totalDebit: originalData.totalCredit,
        totalCredit: originalData.totalDebit,
        lines: reversedLines,
        aiGenerated: false,
        originalEntryId: entryId,
      },
      causationId: originalEntry.event_id,
      userId,
    });

    this.logger.log(`Journal entry reversed: ${entryId} -> ${reversalEntryId}`);

    return {
      reversalEntryId,
      originalEntryId: entryId,
      event,
      status: 'reversed',
    };
  }
}
