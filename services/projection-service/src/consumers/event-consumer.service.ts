import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { ProjectionService } from '../projections/projection.service';
import axios from 'axios';
import { Kafka, Consumer } from 'kafkajs';

@Injectable()
export class EventConsumerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(EventConsumerService.name);
  private kafka: Kafka;
  private consumer: Consumer;

  constructor(private readonly projectionService: ProjectionService) {
    this.kafka = new Kafka({
      clientId: 'projection-service',
      brokers: [(process.env.KAFKA_BROKERS || 'kafka:9092')],
    });

    this.consumer = this.kafka.consumer({
      groupId: 'projection-service-group',
      allowAutoTopicCreation: true,
    });
  }

  async onModuleInit() {
    await this.startConsumer();
  }

  async onModuleDestroy() {
    await this.consumer.disconnect();
    this.logger.log('Kafka consumer disconnected');
  }

  private async startConsumer() {
    try {
      await this.consumer.connect();
      this.logger.log('Kafka consumer connected successfully');

      await this.consumer.subscribe({
        topics: [
          'airp.events.journal-entry-posted',
          'airp.events.invoice-received',
          'airp.events.invoice-issued',
          'airp.events.payment-executed',
        ],
        fromBeginning: true,
      });
      this.logger.log('Subscribed to Kafka topics');

      await this.consumer.run({
        eachMessage: async ({ topic, partition, message }) => {
          try {
            // Handle message value - could be Buffer or already parsed
            let value;
            if (Buffer.isBuffer(message.value)) {
              // It's a Buffer, parse as JSON
              const stringValue = message.value.toString();
              this.logger.debug(`Buffer toString: ${stringValue.substring(0, 100)}`);
              value = JSON.parse(stringValue);
              this.logger.debug(`Parsed Buffer to JSON`);
            } else if (typeof message.value === 'object' && message.value !== null) {
              // Already an object
              value = message.value;
              this.logger.debug(`Message value is already an object: ${JSON.stringify(value).substring(0, 200)}`);
            } else {
              // String or other type - use String() to convert
              value = JSON.parse(String(message.value || '{}'));
              this.logger.debug(`Parsed string to JSON`);
            }

            this.logger.log(`Received message from topic: ${topic}`);

            // Route to appropriate handler based on topic
            switch (topic) {
              case 'airp.events.journal-entry-posted':
                await this.handleJournalEntryPosted(value);
                break;
              case 'airp.events.invoice-received':
                await this.handleInvoiceReceived(value);
                break;
              case 'airp.events.invoice-issued':
                await this.handleInvoiceIssued(value);
                break;
              case 'airp.events.payment-executed':
                await this.handlePaymentExecuted(value);
                break;
              default:
                this.logger.warn(`Unknown topic: ${topic}`);
            }
          } catch (error) {
            this.logger.error(`Error processing message: ${error.message}`, error.stack);
          }
        },
      });

      this.logger.log('Event consumer initialized and ready to process events');
    } catch (error) {
      this.logger.error(`Failed to start Kafka consumer: ${error.message}`, error.stack);
    }
  }

  async handleJournalEntryPosted(event: any) {
    this.logger.log(`Processing journal-entry-posted event: ${event.event_id}`);

    try {
      // First, materialize the journal entry with vendor/customer dimensions
      await this.projectionService.materializeJournalEntry(event);
      this.logger.log(`Journal entry materialized for event: ${event.event_id}`);

      // Then update GL balances and trial balance
      await this.projectionService.updateTrialBalance(event);
      this.logger.log(`Trial balance updated for event: ${event.event_id}`);
    } catch (error) {
      this.logger.error(`Failed to process journal entry: ${error.message}`, error.stack);
    }
  }

  async handleInvoiceReceived(event: any) {
    this.logger.log(`Processing invoice-received event: ${event.event_id}`);

    try {
      // Update AP aging projection
      await this.projectionService.updateAPAging(event);
      this.logger.log(`AP aging updated for event: ${event.event_id}`);

      // Post GL journal entry for AP invoice
      await this.postAPInvoiceToGL(event);
      this.logger.log(`GL entry posted for AP invoice: ${event.invoice_id}`);
    } catch (error) {
      this.logger.error(`Failed to process invoice-received event: ${error.message}`, error.stack);
    }
  }

  private async postAPInvoiceToGL(invoiceEvent: any): Promise<void> {
    try {
      const ledgerWriterUrl = process.env.LEDGER_WRITER_URL || 'http://ledger-writer:3001';

      // Create GL entry: Debit Expense, Credit AP
      const journalEntry = {
        tenantId: invoiceEvent.tenant_id,
        entryDate: invoiceEvent.invoice_date,
        entryType: 'ap_invoice',
        sourceType: 'AP System',
        sourceRefId: invoiceEvent.invoice_id,
        description: `AP Invoice ${invoiceEvent.invoice_number} - Vendor Invoice`,
        lines: [
          {
            accountCode: '5100', // Operating Expenses (default - should be classified)
            debitAmount: parseFloat(invoiceEvent.total_amount),
            creditAmount: 0,
            description: `Expense - ${invoiceEvent.invoice_number}`,
          },
          {
            accountCode: '2100', // Accounts Payable
            debitAmount: 0,
            creditAmount: parseFloat(invoiceEvent.total_amount),
            description: `AP - ${invoiceEvent.invoice_number}`,
            vendorId: invoiceEvent.vendor_id,
            invoiceNumber: invoiceEvent.invoice_number,
            dueDate: invoiceEvent.due_date,
            paymentTerms: 'Net 30',
          },
        ],
      };

      await axios.post(`${ledgerWriterUrl}/journal-entries`, journalEntry);
      this.logger.log(`Posted AP invoice ${invoiceEvent.invoice_id} to GL`);
    } catch (error) {
      this.logger.error(`Failed to post AP invoice to GL: ${error.message}`, error.stack);
      throw error;
    }
  }

  async handleInvoiceIssued(event: any) {
    this.logger.log(`Processing invoice-issued event: ${event.event_id}`);

    try {
      // Update AR aging projection
      await this.projectionService.updateARAging(event);
      this.logger.log(`AR aging updated for event: ${event.event_id}`);

      // Post GL journal entry for AR invoice
      await this.postARInvoiceToGL(event);
      this.logger.log(`GL entry posted for AR invoice: ${event.invoice_id}`);
    } catch (error) {
      this.logger.error(`Failed to process invoice-issued event: ${error.message}`, error.stack);
    }
  }

  private async postARInvoiceToGL(invoiceEvent: any): Promise<void> {
    try {
      const ledgerWriterUrl = process.env.LEDGER_WRITER_URL || 'http://ledger-writer:3001';

      // Create GL entry: Debit AR, Credit Revenue
      const journalEntry = {
        tenantId: invoiceEvent.tenant_id,
        entryDate: invoiceEvent.invoice_date,
        entryType: 'ar_invoice',
        sourceType: 'AR System',
        sourceRefId: invoiceEvent.invoice_id,
        description: `AR Invoice ${invoiceEvent.invoice_number}`,
        lines: [
          {
            accountCode: '1200', // Accounts Receivable
            debitAmount: invoiceEvent.total_amount,
            creditAmount: 0,
            description: `AR - ${invoiceEvent.invoice_number}`,
            customerId: invoiceEvent.customer_id,
            invoiceNumber: invoiceEvent.invoice_number,
            dueDate: invoiceEvent.due_date,
          },
          {
            accountCode: '4000', // Revenue
            debitAmount: 0,
            creditAmount: invoiceEvent.total_amount,
            description: `Revenue - ${invoiceEvent.invoice_number}`,
          },
        ],
      };

      await axios.post(`${ledgerWriterUrl}/journal-entries`, journalEntry);
      this.logger.log(`Posted AR invoice ${invoiceEvent.invoice_id} to GL`);
    } catch (error) {
      this.logger.error(`Failed to post AR invoice to GL: ${error.message}`);
      throw error;
    }
  }

  async handlePaymentExecuted(event: any) {
    this.logger.log(`Processing payment-executed event: ${event.event_id}`);

    try {
      if (event.payment_type === 'AP') {
        await this.projectionService.updateAPAging(event);
      } else if (event.payment_type === 'AR') {
        await this.projectionService.updateARAging(event);
      }
      this.logger.log(`Aging updated for payment event: ${event.event_id}`);
    } catch (error) {
      this.logger.error(`Failed to update aging: ${error.message}`, error.stack);
    }
  }
}
