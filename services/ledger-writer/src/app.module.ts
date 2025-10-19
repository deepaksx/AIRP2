import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TerminusModule } from '@nestjs/terminus';
import { EventStoreModule } from './events/event-store.module';
import { JournalEntryModule } from './domain/journal-entry.module';
import { ChartOfAccountsModule } from './master-data/chart-of-accounts.module';
import { HealthController } from './health/health.controller';
import { MetricsController } from './health/metrics.controller';

@Module({
  imports: [
    // Configuration
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env.local', '.env'],
    }),

    // Database connection
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        host: configService.get('POSTGRES_HOST', 'localhost'),
        port: configService.get('POSTGRES_PORT', 5432),
        username: configService.get('POSTGRES_USER', 'airp_admin'),
        password: configService.get('POSTGRES_PASSWORD', 'airp_secure_2024'),
        database: configService.get('POSTGRES_DB', 'airp_master'),
        entities: [__dirname + '/**/*.entity{.ts,.js}'],
        synchronize: false, // Use migrations in production
        logging: configService.get('NODE_ENV') === 'development',
        maxQueryExecutionTime: 1000,
        extra: {
          max: 20,
          idleTimeoutMillis: 30000,
          connectionTimeoutMillis: 2000,
        },
      }),
    }),

    // Health checks
    TerminusModule,

    // Domain modules
    EventStoreModule,
    JournalEntryModule,
    ChartOfAccountsModule,
  ],
  controllers: [HealthController, MetricsController],
})
export class AppModule {}
