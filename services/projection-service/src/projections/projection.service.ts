import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { TrialBalanceEntity } from './trial-balance.entity';
import { APAgingEntity } from './ap-aging.entity';
import { ARAgingEntity } from './ar-aging.entity';
import { GLBalanceEntity } from './gl-balance.entity';
import { ChartOfAccountsEntity } from './chart-of-accounts.entity';
import { JournalEntryEntity } from './journal-entry.entity';
import { JournalEntryLineEntity } from './journal-entry-line.entity';
import { APInvoiceEntity } from './ap-invoice.entity';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class ProjectionService {
  private readonly logger = new Logger(ProjectionService.name);

  constructor(
    @InjectRepository(TrialBalanceEntity)
    private trialBalanceRepo: Repository<TrialBalanceEntity>,
    @InjectRepository(APAgingEntity)
    private apAgingRepo: Repository<APAgingEntity>,
    @InjectRepository(ARAgingEntity)
    private arAgingRepo: Repository<ARAgingEntity>,
    @InjectRepository(GLBalanceEntity)
    private glBalanceRepo: Repository<GLBalanceEntity>,
    @InjectRepository(ChartOfAccountsEntity)
    private coaRepo: Repository<ChartOfAccountsEntity>,
    @InjectRepository(JournalEntryEntity)
    private journalEntryRepo: Repository<JournalEntryEntity>,
    @InjectRepository(JournalEntryLineEntity)
    private journalEntryLineRepo: Repository<JournalEntryLineEntity>,
    @InjectRepository(APInvoiceEntity)
    private apInvoiceRepo: Repository<APInvoiceEntity>,
    private dataSource: DataSource,
  ) {}

  async materializeJournalEntry(event: any): Promise<void> {
    this.logger.log(`Materializing journal entry from event: ${event.event_id}`);

    try {
      const jeData = event.event_data;

      // Create journal entry record
      const journalEntry = this.journalEntryRepo.create({
        entry_id: event.aggregate_id,
        tenant_id: event.tenant_id,
        entry_number: jeData.entryNumber,
        entry_date: new Date(jeData.entryDate),
        posting_date: new Date(jeData.postingDate || jeData.entryDate),
        entry_type: jeData.entryType,
        source_type: jeData.sourceType || 'Manual',
        description: jeData.description,
        currency: jeData.currency || 'AED',
        total_debit: parseFloat(jeData.totalDebit),
        total_credit: parseFloat(jeData.totalCredit),
        status: 'posted',
        posted_by: event.user_id,
        posted_at: new Date(event.timestamp),
        ai_confidence_score: jeData.aiConfidenceScore ? parseFloat(jeData.aiConfidenceScore) : null,
        metadata: jeData.metadata || {},
      });

      await this.journalEntryRepo.save(journalEntry);
      this.logger.log(`Created journal entry: ${journalEntry.entry_id}`);

      // Create journal entry lines with sub-ledger dimensions
      for (const line of jeData.lines) {
        // Look up account_id from chart of accounts
        const coaEntry = await this.coaRepo.findOne({
          where: {
            tenant_id: event.tenant_id,
            account_code: line.accountCode,
          },
        });

        if (!coaEntry) {
          this.logger.warn(`Account code ${line.accountCode} not found`);
          continue;
        }

        const journalEntryLine = this.journalEntryLineRepo.create({
          line_id: uuidv4(),
          entry_id: event.aggregate_id,
          tenant_id: event.tenant_id,
          line_number: line.lineNumber,
          account_id: coaEntry.account_id,
          debit_amount: parseFloat(line.debitAmount || '0'),
          credit_amount: parseFloat(line.creditAmount || '0'),
          currency: jeData.currency || 'AED',
          exchange_rate: 1.0,
          description: line.description,
          // CRITICAL: Map vendor/customer to dimensions
          dimension_1: line.vendorId || null,     // AP sub-ledger
          dimension_2: line.customerId || null,   // AR sub-ledger
          dimension_3: line.projectId || null,    // Project tracking
          dimension_4: line.costCenterId || null, // Cost center
          // Store invoice details in metadata
          metadata: {
            invoiceNumber: line.invoiceNumber,
            dueDate: line.dueDate,
            paymentTerms: line.paymentTerms,
            ...line.metadata,
          },
        });

        await this.journalEntryLineRepo.save(journalEntryLine);
        this.logger.log(
          `Created JE line ${line.lineNumber}: Account ${line.accountCode}, ` +
          `Vendor: ${line.vendorId || 'N/A'}, Customer: ${line.customerId || 'N/A'}`
        );
      }

    } catch (error) {
      this.logger.error(`Failed to materialize journal entry: ${error.message}`, error.stack);
      throw error;
    }
  }

  async updateTrialBalance(event: any): Promise<void> {
    this.logger.log(`Updating GL balances for tenant: ${event.tenant_id}`);

    try {
      const journalEntryData = event.event_data;
      const lines = journalEntryData.lines || [];
      const entryDate = new Date(journalEntryData.entryDate);
      const fiscalYear = entryDate.getFullYear();
      const fiscalPeriod = entryDate.getMonth() + 1; // 1-12
      const currency = journalEntryData.currency || 'AED';

      for (const line of lines) {
        // Look up account_id from chart of accounts
        const coaEntry = await this.coaRepo.findOne({
          where: {
            tenant_id: event.tenant_id,
            account_code: line.accountCode,
          },
        });

        if (!coaEntry) {
          this.logger.warn(
            `Account code ${line.accountCode} not found in chart of accounts for tenant ${event.tenant_id}`
          );
          continue;
        }

        // Find or create GL balance entry
        let glBalance = await this.glBalanceRepo.findOne({
          where: {
            tenant_id: event.tenant_id,
            account_id: coaEntry.account_id,
            fiscal_year: fiscalYear,
            fiscal_period: fiscalPeriod,
            currency: currency,
          },
        });

        if (!glBalance) {
          // Create new GL balance entry
          glBalance = this.glBalanceRepo.create({
            tenant_id: event.tenant_id,
            account_id: coaEntry.account_id,
            fiscal_year: fiscalYear,
            fiscal_period: fiscalPeriod,
            currency: currency,
            debit_amount: 0,
            credit_amount: 0,
            balance: 0,
            last_event_id: event.event_id,
          });
        }

        // Update balances
        const debitAmount = parseFloat(line.debitAmount || '0');
        const creditAmount = parseFloat(line.creditAmount || '0');

        glBalance.debit_amount = parseFloat(glBalance.debit_amount.toString()) + debitAmount;
        glBalance.credit_amount = parseFloat(glBalance.credit_amount.toString()) + creditAmount;

        // Calculate balance based on normal balance type
        if (coaEntry.normal_balance === 'DEBIT') {
          glBalance.balance = glBalance.debit_amount - glBalance.credit_amount;
        } else {
          glBalance.balance = glBalance.credit_amount - glBalance.debit_amount;
        }

        glBalance.last_updated = new Date();
        glBalance.last_event_id = event.event_id;

        await this.glBalanceRepo.save(glBalance);

        this.logger.log(
          `Updated GL balance for account ${line.accountCode}: ` +
          `Debit=${glBalance.debit_amount}, Credit=${glBalance.credit_amount}, Balance=${glBalance.balance}`
        );
      }

      // Refresh the trial balance materialized view
      await this.dataSource.query('REFRESH MATERIALIZED VIEW trial_balance');
      this.logger.log(`Trial balance materialized view refreshed for event ${event.event_id}`);
    } catch (error) {
      this.logger.error(`Failed to update GL balances: ${error.message}`, error.stack);
      throw error;
    }
  }

  async updateAPAging(event: any): Promise<void> {
    this.logger.log(`Updating AP aging for tenant: ${event.tenant_id}`);

    try {
      const asOfDate = new Date(); // Use current date for aging calculation

      // Query all unpaid AP invoices for the tenant
      const unpaidInvoices = await this.apInvoiceRepo.find({
        where: {
          tenant_id: event.tenant_id,
          payment_status: 'unpaid',
        },
      });

      this.logger.log(`Found ${unpaidInvoices.length} unpaid AP invoices to process for aging`);

      for (const invoice of unpaidInvoices) {
        // Calculate days outstanding (negative if not yet due, positive if overdue)
        const daysOutstanding = this.calculateDaysOutstanding(invoice.due_date, asOfDate);

        // Determine which bucket the outstanding amount belongs to
        const buckets = this.calculateAgingBuckets(invoice.amount_outstanding, daysOutstanding);

        // Find or create AP aging record
        let apAging = await this.apAgingRepo.findOne({
          where: {
            tenant_id: event.tenant_id,
            invoice_id: invoice.invoice_id,
            as_of_date: asOfDate,
          },
        });

        if (!apAging) {
          // Create new AP aging record
          apAging = this.apAgingRepo.create({
            tenant_id: event.tenant_id,
            vendor_id: invoice.vendor_id,
            invoice_id: invoice.invoice_id,
            currency: invoice.currency,
            total_outstanding: invoice.amount_outstanding,
            current_amount: buckets.current,
            bucket_30: buckets.bucket_30,
            bucket_60: buckets.bucket_60,
            bucket_90: buckets.bucket_90,
            bucket_120_plus: buckets.bucket_120_plus,
            as_of_date: asOfDate,
          });
        } else {
          // Update existing AP aging record
          apAging.total_outstanding = invoice.amount_outstanding;
          apAging.current_amount = buckets.current;
          apAging.bucket_30 = buckets.bucket_30;
          apAging.bucket_60 = buckets.bucket_60;
          apAging.bucket_90 = buckets.bucket_90;
          apAging.bucket_120_plus = buckets.bucket_120_plus;
          apAging.last_updated = new Date();
        }

        await this.apAgingRepo.save(apAging);

        this.logger.log(
          `Updated AP aging for invoice ${invoice.invoice_number}: ` +
          `Total=${invoice.amount_outstanding}, ` +
          `Current=${buckets.current}, ` +
          `1-30=${buckets.bucket_30}, ` +
          `31-60=${buckets.bucket_60}, ` +
          `61-90=${buckets.bucket_90}, ` +
          `90+=${buckets.bucket_120_plus}`
        );
      }

      this.logger.log(`AP aging calculation completed for tenant ${event.tenant_id}`);
    } catch (error) {
      this.logger.error(`Failed to update AP aging: ${error.message}`, error.stack);
      throw error;
    }
  }

  private calculateDaysOutstanding(dueDate: Date, asOfDate: Date): number {
    const due = new Date(dueDate);
    const asOf = new Date(asOfDate);
    const diffTime = asOf.getTime() - due.getTime();
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
    return diffDays;
  }

  private calculateAgingBuckets(
    outstandingAmount: number,
    daysOutstanding: number,
  ): {
    current: number;
    bucket_30: number;
    bucket_60: number;
    bucket_90: number;
    bucket_120_plus: number;
  } {
    const buckets = {
      current: 0,
      bucket_30: 0,
      bucket_60: 0,
      bucket_90: 0,
      bucket_120_plus: 0,
    };

    const amount = parseFloat(outstandingAmount.toString());

    if (daysOutstanding < 0) {
      // Not yet due - goes to current bucket
      buckets.current = amount;
    } else if (daysOutstanding <= 30) {
      // 1-30 days overdue
      buckets.bucket_30 = amount;
    } else if (daysOutstanding <= 60) {
      // 31-60 days overdue
      buckets.bucket_60 = amount;
    } else if (daysOutstanding <= 90) {
      // 61-90 days overdue
      buckets.bucket_90 = amount;
    } else {
      // 90+ days overdue
      buckets.bucket_120_plus = amount;
    }

    return buckets;
  }

  async updateARAging(event: any): Promise<void> {
    this.logger.log(`Updating AR aging for tenant: ${event.tenant_id}`);

    // In production, this would calculate aging buckets and update AR aging table
    this.logger.log(`AR aging projection would be updated with event data`);
  }
}
