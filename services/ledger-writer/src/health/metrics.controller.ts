import { Controller, Get, Header } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiExcludeEndpoint } from '@nestjs/swagger';
import { register, collectDefaultMetrics, Counter, Histogram } from 'prom-client';

// Initialize Prometheus metrics
collectDefaultMetrics({ prefix: 'airp_ledger_writer_' });

export const eventWriteCounter = new Counter({
  name: 'airp_ledger_writer_events_written_total',
  help: 'Total number of events written to event store',
  labelNames: ['event_type', 'tenant_id'],
});

export const eventWriteDuration = new Histogram({
  name: 'airp_ledger_writer_event_write_duration_seconds',
  help: 'Duration of event write operations',
  labelNames: ['event_type'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1],
});

export const journalEntryCounter = new Counter({
  name: 'airp_ledger_writer_journal_entries_total',
  help: 'Total number of journal entries created',
  labelNames: ['entry_type', 'tenant_id'],
});

@ApiTags('health')
@Controller('metrics')
export class MetricsController {
  @Get()
  @Header('Content-Type', register.contentType)
  @ApiOperation({ summary: 'Prometheus metrics endpoint' })
  @ApiExcludeEndpoint()
  async getMetrics() {
    return register.metrics();
  }
}
