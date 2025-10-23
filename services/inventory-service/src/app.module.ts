import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TerminusModule } from '@nestjs/terminus';
import { ClientsModule, Transport } from '@nestjs/microservices';
import { HealthController } from './health/health.controller';
import { InventoryModule } from './inventory/inventory.module';
import { ProcurementModule } from './procurement/procurement.module';
import { SalesModule } from './sales/sales.module';
import { CopaModule } from './copa/copa.module';

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
    ClientsModule.register([
      {
        name: 'KAFKA_SERVICE',
        transport: Transport.KAFKA,
        options: {
          client: {
            clientId: 'inventory-service',
            brokers: [(process.env.KAFKA_BROKERS || 'localhost:19092')],
          },
        },
      },
    ]),
    TerminusModule,
    InventoryModule,
    ProcurementModule,
    SalesModule,
    CopaModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
