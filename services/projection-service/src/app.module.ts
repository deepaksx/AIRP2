import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './health/health.controller';
import { EventConsumerService } from './consumers/event-consumer.service';
import { ProjectionService } from './projections/projection.service';
import { TrialBalanceEntity } from './projections/trial-balance.entity';
import { APAgingEntity } from './projections/ap-aging.entity';
import { ARAgingEntity } from './projections/ar-aging.entity';
import { GLBalanceEntity } from './projections/gl-balance.entity';
import { ChartOfAccountsEntity } from './projections/chart-of-accounts.entity';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.POSTGRES_HOST || 'localhost',
      port: parseInt(process.env.POSTGRES_PORT || '5432'),
      username: process.env.POSTGRES_USER || 'airp_admin',
      password: process.env.POSTGRES_PASSWORD || 'airp_secure_2024',
      database: process.env.POSTGRES_DB || 'airp_master',
      entities: [TrialBalanceEntity, APAgingEntity, ARAgingEntity, GLBalanceEntity, ChartOfAccountsEntity],
      synchronize: false,
    }),
    TypeOrmModule.forFeature([TrialBalanceEntity, APAgingEntity, ARAgingEntity, GLBalanceEntity, ChartOfAccountsEntity]),
    TerminusModule,
  ],
  controllers: [HealthController],
  providers: [EventConsumerService, ProjectionService],
})
export class AppModule {}
