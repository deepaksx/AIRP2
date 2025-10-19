import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ClientsModule, Transport } from '@nestjs/microservices';
import { APInvoiceEntity } from './ap-invoice.entity';
import { APInvoiceLineEntity } from './ap-invoice-line.entity';
import { InvoicesController } from './invoices.controller';
import { InvoicesService } from './invoices.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([APInvoiceEntity, APInvoiceLineEntity]),
    ClientsModule.register([
      {
        name: 'KAFKA_SERVICE',
        transport: Transport.KAFKA,
        options: {
          client: {
            clientId: 'ap-service-invoices',
            brokers: [(process.env.KAFKA_BROKERS || 'localhost:19092')],
          },
        },
      },
      {
        name: 'AI_SERVICE',
        transport: Transport.TCP,
        options: {
          host: process.env.AI_AUTO_ACCOUNTING_HOST || 'localhost',
          port: parseInt(process.env.AI_AUTO_ACCOUNTING_PORT || '8001'),
        },
      },
    ]),
  ],
  controllers: [InvoicesController],
  providers: [InvoicesService],
  exports: [InvoicesService],
})
export class InvoicesModule {}
