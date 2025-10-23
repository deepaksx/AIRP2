import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InventoryController } from './inventory.controller';
import { InventoryService } from './inventory.service';
import { InventoryItem } from './entities/inventory-item.entity';
import { Warehouse } from './entities/warehouse.entity';
import { InventoryStock } from './entities/inventory-stock.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      InventoryItem,
      Warehouse,
      InventoryStock,
    ]),
  ],
  controllers: [InventoryController],
  providers: [InventoryService],
  exports: [InventoryService],
})
export class InventoryModule {}
