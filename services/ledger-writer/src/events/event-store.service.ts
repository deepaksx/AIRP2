import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { EventStoreEntity } from './event-store.entity';
import { v4 as uuidv4 } from 'uuid';
import { createHash } from 'crypto';
import { eventWriteCounter, eventWriteDuration } from '../health/metrics.controller';

export interface CreateEventDto {
  tenantId: string;
  aggregateId: string;
  aggregateType: string;
  eventType: string;
  eventData: any;
  eventMetadata?: any;
  causationId?: string;
  correlationId?: string;
  userId?: string;
}

@Injectable()
export class EventStoreService {
  private readonly logger = new Logger(EventStoreService.name);

  constructor(
    @InjectRepository(EventStoreEntity)
    private eventRepository: Repository<EventStoreEntity>,
    private dataSource: DataSource,
  ) {}

  async appendEvent(dto: CreateEventDto): Promise<EventStoreEntity> {
    const timer = eventWriteDuration.startTimer({ event_type: dto.eventType });

    try {
      const event = this.eventRepository.create({
        event_id: uuidv4(),
        tenant_id: dto.tenantId,
        aggregate_id: dto.aggregateId,
        aggregate_type: dto.aggregateType,
        event_type: dto.eventType,
        event_version: 1,
        event_data: dto.eventData,
        event_metadata: dto.eventMetadata || {},
        causation_id: dto.causationId,
        correlation_id: dto.correlationId || uuidv4(),
        user_id: dto.userId,
        timestamp: new Date(),
      });

      // Calculate checksum for integrity
      event.checksum = this.calculateChecksum(event);

      const savedEvent = await this.eventRepository.save(event);

      // Update metrics
      eventWriteCounter.inc({
        event_type: dto.eventType,
        tenant_id: dto.tenantId,
      });

      this.logger.log(
        `Event appended: ${dto.eventType} for aggregate ${dto.aggregateId}`,
      );

      // TODO: Publish to Kafka for projection consumers

      return savedEvent;
    } catch (error) {
      this.logger.error(
        `Failed to append event: ${dto.eventType}`,
        error.stack,
      );
      throw error;
    } finally {
      timer();
    }
  }

  async appendEvents(dtos: CreateEventDto[]): Promise<EventStoreEntity[]> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const events: EventStoreEntity[] = [];

      for (const dto of dtos) {
        const event = this.eventRepository.create({
          event_id: uuidv4(),
          tenant_id: dto.tenantId,
          aggregate_id: dto.aggregateId,
          aggregate_type: dto.aggregateType,
          event_type: dto.eventType,
          event_version: 1,
          event_data: dto.eventData,
          event_metadata: dto.eventMetadata || {},
          causation_id: dto.causationId,
          correlation_id: dto.correlationId || uuidv4(),
          user_id: dto.userId,
          timestamp: new Date(),
        });

        event.checksum = this.calculateChecksum(event);
        events.push(event);
      }

      const savedEvents = await queryRunner.manager.save(events);
      await queryRunner.commitTransaction();

      this.logger.log(`Batch of ${events.length} events appended`);

      return savedEvents;
    } catch (error) {
      await queryRunner.rollbackTransaction();
      this.logger.error('Failed to append batch of events', error.stack);
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async getEventsByAggregate(
    aggregateId: string,
    tenantId: string,
  ): Promise<EventStoreEntity[]> {
    return this.eventRepository.find({
      where: {
        aggregate_id: aggregateId,
        tenant_id: tenantId,
      },
      order: {
        sequence_number: 'ASC',
      },
    });
  }

  async getEventsByType(
    eventType: string,
    tenantId: string,
    limit: number = 100,
  ): Promise<EventStoreEntity[]> {
    return this.eventRepository.find({
      where: {
        event_type: eventType,
        tenant_id: tenantId,
      },
      order: {
        timestamp: 'DESC',
      },
      take: limit,
    });
  }

  async getEventsByCorrelation(
    correlationId: string,
  ): Promise<EventStoreEntity[]> {
    return this.eventRepository.find({
      where: {
        correlation_id: correlationId,
      },
      order: {
        sequence_number: 'ASC',
      },
    });
  }

  async getRecentEvents(
    tenantId: string,
    limit: number = 100,
  ): Promise<EventStoreEntity[]> {
    return this.eventRepository.find({
      where: {
        tenant_id: tenantId,
      },
      order: {
        timestamp: 'DESC',
      },
      take: limit,
    });
  }

  async verifyEventIntegrity(eventId: string): Promise<boolean> {
    const event = await this.eventRepository.findOne({
      where: { event_id: eventId },
    });

    if (!event) {
      return false;
    }

    const calculatedChecksum = this.calculateChecksum(event);
    return calculatedChecksum === event.checksum;
  }

  private calculateChecksum(event: Partial<EventStoreEntity>): string {
    const data = `${event.aggregate_id}${event.event_type}${JSON.stringify(event.event_data)}${event.timestamp}`;
    return createHash('sha256').update(data).digest('hex');
  }

  async getEventStats(tenantId: string): Promise<any> {
    const result = await this.eventRepository
      .createQueryBuilder('event')
      .select('event.event_type', 'event_type')
      .addSelect('COUNT(*)', 'count')
      .where('event.tenant_id = :tenantId', { tenantId })
      .groupBy('event.event_type')
      .orderBy('count', 'DESC')
      .getRawMany();

    return result;
  }
}
