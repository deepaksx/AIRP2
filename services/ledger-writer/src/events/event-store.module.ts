import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EventStoreEntity } from './event-store.entity';
import { EventStoreService } from './event-store.service';
import { EventStoreController } from './event-store.controller';

@Module({
  imports: [TypeOrmModule.forFeature([EventStoreEntity])],
  controllers: [EventStoreController],
  providers: [EventStoreService],
  exports: [EventStoreService],
})
export class EventStoreModule {}
