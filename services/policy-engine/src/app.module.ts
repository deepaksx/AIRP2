import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './health/health.controller';
import { PolicyController } from './policy.controller';
import { PolicyService } from './policy.service';
import { ApprovalWorkflowEntity } from './entities/approval-workflow.entity';

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
    TypeOrmModule.forFeature([ApprovalWorkflowEntity]),
    TerminusModule,
  ],
  controllers: [HealthController, PolicyController],
  providers: [PolicyService],
})
export class AppModule {}
