import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiParam, ApiQuery } from '@nestjs/swagger';
import { EventStoreService, CreateEventDto } from './event-store.service';

@ApiTags('events')
@Controller('events')
export class EventStoreController {
  constructor(private readonly eventStoreService: EventStoreService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Append a new event to the event store' })
  @ApiResponse({ status: 201, description: 'Event successfully appended' })
  @ApiResponse({ status: 400, description: 'Invalid event data' })
  async appendEvent(@Body() createEventDto: CreateEventDto) {
    return this.eventStoreService.appendEvent(createEventDto);
  }

  @Post('batch')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Append multiple events in a transaction' })
  @ApiResponse({ status: 201, description: 'Events successfully appended' })
  @ApiResponse({ status: 400, description: 'Invalid event data' })
  async appendEvents(@Body() createEventDtos: CreateEventDto[]) {
    return this.eventStoreService.appendEvents(createEventDtos);
  }

  @Get('aggregate/:aggregateId')
  @ApiOperation({ summary: 'Get all events for an aggregate' })
  @ApiParam({ name: 'aggregateId', description: 'Aggregate UUID' })
  @ApiQuery({ name: 'tenantId', description: 'Tenant UUID' })
  @ApiResponse({ status: 200, description: 'Events retrieved successfully' })
  async getEventsByAggregate(
    @Param('aggregateId') aggregateId: string,
    @Query('tenantId') tenantId: string,
  ) {
    return this.eventStoreService.getEventsByAggregate(aggregateId, tenantId);
  }

  @Get('type/:eventType')
  @ApiOperation({ summary: 'Get events by type' })
  @ApiParam({ name: 'eventType', description: 'Event type name' })
  @ApiQuery({ name: 'tenantId', description: 'Tenant UUID' })
  @ApiQuery({ name: 'limit', required: false, description: 'Max results', type: Number })
  @ApiResponse({ status: 200, description: 'Events retrieved successfully' })
  async getEventsByType(
    @Param('eventType') eventType: string,
    @Query('tenantId') tenantId: string,
    @Query('limit') limit?: number,
  ) {
    return this.eventStoreService.getEventsByType(eventType, tenantId, limit);
  }

  @Get('correlation/:correlationId')
  @ApiOperation({ summary: 'Get all events by correlation ID' })
  @ApiParam({ name: 'correlationId', description: 'Correlation UUID' })
  @ApiResponse({ status: 200, description: 'Events retrieved successfully' })
  async getEventsByCorrelation(@Param('correlationId') correlationId: string) {
    return this.eventStoreService.getEventsByCorrelation(correlationId);
  }

  @Get('recent')
  @ApiOperation({ summary: 'Get recent events' })
  @ApiQuery({ name: 'tenantId', description: 'Tenant UUID' })
  @ApiQuery({ name: 'limit', required: false, description: 'Max results', type: Number })
  @ApiResponse({ status: 200, description: 'Events retrieved successfully' })
  async getRecentEvents(
    @Query('tenantId') tenantId: string,
    @Query('limit') limit?: number,
  ) {
    return this.eventStoreService.getRecentEvents(tenantId, limit);
  }

  @Get('verify/:eventId')
  @ApiOperation({ summary: 'Verify event integrity via checksum' })
  @ApiParam({ name: 'eventId', description: 'Event UUID' })
  @ApiResponse({ status: 200, description: 'Integrity verification result' })
  async verifyEventIntegrity(@Param('eventId') eventId: string) {
    const isValid = await this.eventStoreService.verifyEventIntegrity(eventId);
    return {
      eventId,
      isValid,
      message: isValid ? 'Event integrity verified' : 'Event integrity check failed',
    };
  }

  @Get('stats')
  @ApiOperation({ summary: 'Get event statistics by type' })
  @ApiQuery({ name: 'tenantId', description: 'Tenant UUID' })
  @ApiResponse({ status: 200, description: 'Event statistics' })
  async getEventStats(@Query('tenantId') tenantId: string) {
    return this.eventStoreService.getEventStats(tenantId);
  }
}
