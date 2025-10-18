import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ClientsModule, Transport } from '@nestjs/microservices';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { EventStoreEntity } from './event-store.entity';
import { EventStoreService } from './event-store.service';
import { EventStoreController } from './event-store.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([EventStoreEntity]),
    ClientsModule.registerAsync([
      {
        name: 'KAFKA_SERVICE',
        inject: [ConfigService],
        useFactory: (configService: ConfigService) => ({
          transport: Transport.KAFKA,
          options: {
            client: {
              brokers: [configService.get('KAFKA_BROKERS', 'kafka:9092')],
            },
            producer: {
              allowAutoTopicCreation: true,
            },
            serializer: {
              serialize(value: any) {
                return Buffer.from(JSON.stringify(value));
              },
            },
          },
        }),
      },
    ]),
  ],
  controllers: [EventStoreController],
  providers: [EventStoreService],
  exports: [EventStoreService],
})
export class EventStoreModule {}
