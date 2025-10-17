import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './health/health.controller';
import { BudgetEntity } from './entities/budget.entity';
import { BudgetLineEntity } from './entities/budget-line.entity';
import { FPnAController } from './fpna.controller';
import { FPnAService } from './fpna.service';

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
      autoLoadEntities: true,
      synchronize: false,
    }),
    TypeOrmModule.forFeature([BudgetEntity, BudgetLineEntity]),
    TerminusModule,
  ],
  controllers: [HealthController, FPnAController],
  providers: [FPnAService],
})
export class AppModule {}
