import { Controller, Get } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

@Controller('health')
export class HealthController {
  constructor(
    @InjectDataSource()
    private dataSource: DataSource,
  ) {}

  @Get()
  async check() {
    const dbConnected = this.dataSource.isInitialized;

    return {
      status: dbConnected ? 'healthy' : 'unhealthy',
      service: 'user-management-service',
      version: '2.13.0',
      timestamp: new Date().toISOString(),
      database: dbConnected ? 'connected' : 'disconnected',
    };
  }
}
