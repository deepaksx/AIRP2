import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { EventPattern, Payload } from '@nestjs/microservices';
import { ProjectionService } from '../projections/projection.service';

@Injectable()
export class EventConsumerService implements OnModuleInit {
  private readonly logger = new Logger(EventConsumerService.name);

  constructor(private readonly projectionService: ProjectionService) {}

  onModuleInit() {
    this.logger.log('Event consumer initialized and ready to process events');
  }

  @EventPattern('airp.events.journal-entry-posted')
  async handleJournalEntryPosted(@Payload() message: any) {
    this.logger.log(`Processing journal-entry-posted event: ${message.value.event_id}`);

    try {
      await this.projectionService.updateTrialBalance(message.value);
      this.logger.log(`Trial balance updated for event: ${message.value.event_id}`);
    } catch (error) {
      this.logger.error(`Failed to update trial balance: ${error.message}`, error.stack);
    }
  }

  @EventPattern('airp.events.invoice-received')
  async handleInvoiceReceived(@Payload() message: any) {
    this.logger.log(`Processing invoice-received event: ${message.value.event_id}`);

    try {
      await this.projectionService.updateAPAging(message.value);
      this.logger.log(`AP aging updated for event: ${message.value.event_id}`);
    } catch (error) {
      this.logger.error(`Failed to update AP aging: ${error.message}`, error.stack);
    }
  }

  @EventPattern('airp.events.invoice-issued')
  async handleInvoiceIssued(@Payload() message: any) {
    this.logger.log(`Processing invoice-issued event: ${message.value.event_id}`);

    try {
      await this.projectionService.updateARAging(message.value);
      this.logger.log(`AR aging updated for event: ${message.value.event_id}`);
    } catch (error) {
      this.logger.error(`Failed to update AR aging: ${error.message}`, error.stack);
    }
  }

  @EventPattern('airp.events.payment-executed')
  async handlePaymentExecuted(@Payload() message: any) {
    this.logger.log(`Processing payment-executed event: ${message.value.event_id}`);

    try {
      if (message.value.payment_type === 'AP') {
        await this.projectionService.updateAPAging(message.value);
      } else if (message.value.payment_type === 'AR') {
        await this.projectionService.updateARAging(message.value);
      }
      this.logger.log(`Aging updated for payment event: ${message.value.event_id}`);
    } catch (error) {
      this.logger.error(`Failed to update aging: ${error.message}`, error.stack);
    }
  }
}
