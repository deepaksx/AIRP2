import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository, InjectDataSource } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { InventoryItem } from './entities/inventory-item.entity';
import { Warehouse } from './entities/warehouse.entity';
import { InventoryStock } from './entities/inventory-stock.entity';

@Injectable()
export class InventoryService {
  private readonly logger = new Logger(InventoryService.name);

  constructor(
    @InjectRepository(InventoryItem)
    private itemsRepository: Repository<InventoryItem>,
    @InjectRepository(Warehouse)
    private warehousesRepository: Repository<Warehouse>,
    @InjectRepository(InventoryStock)
    private stockRepository: Repository<InventoryStock>,
    @InjectDataSource()
    private dataSource: DataSource,
  ) {}

  // ===== INVENTORY ITEMS =====

  async createItem(createItemDto: any): Promise<InventoryItem> {
    this.logger.log(`Creating inventory item: ${createItemDto.item_code}`);
    const item = this.itemsRepository.create(createItemDto);
    return await this.itemsRepository.save(item);
  }

  async findAllItems(tenantId: string, filters?: any): Promise<InventoryItem[]> {
    const query = this.itemsRepository
      .createQueryBuilder('item')
      .where('item.tenant_id = :tenantId', { tenantId });

    if (filters?.item_type) {
      query.andWhere('item.item_type = :item_type', { item_type: filters.item_type });
    }

    if (filters?.is_active !== undefined) {
      query.andWhere('item.is_active = :is_active', { is_active: filters.is_active });
    }

    if (filters?.search) {
      query.andWhere(
        '(item.item_code ILIKE :search OR item.item_name ILIKE :search)',
        { search: `%${filters.search}%` }
      );
    }

    return await query.orderBy('item.item_code', 'ASC').getMany();
  }

  async findItemById(itemId: string): Promise<InventoryItem> {
    const item = await this.itemsRepository.findOne({ where: { item_id: itemId } });
    if (!item) {
      throw new NotFoundException(`Item ${itemId} not found`);
    }
    return item;
  }

  async updateItem(itemId: string, updateItemDto: any): Promise<InventoryItem> {
    this.logger.log(`Updating inventory item: ${itemId}`);
    await this.itemsRepository.update(itemId, updateItemDto);
    return await this.findItemById(itemId);
  }

  async deleteItem(itemId: string): Promise<void> {
    this.logger.log(`Deleting inventory item: ${itemId}`);
    await this.itemsRepository.delete(itemId);
  }

  // ===== WAREHOUSES =====

  async createWarehouse(createWarehouseDto: any): Promise<Warehouse> {
    this.logger.log(`Creating warehouse: ${createWarehouseDto.warehouse_code}`);
    const warehouse = this.warehousesRepository.create(createWarehouseDto);
    return await this.warehousesRepository.save(warehouse);
  }

  async findAllWarehouses(tenantId: string): Promise<Warehouse[]> {
    return await this.warehousesRepository.find({
      where: { tenant_id: tenantId },
      order: { warehouse_code: 'ASC' },
    });
  }

  async findWarehouseById(warehouseId: string): Promise<Warehouse> {
    const warehouse = await this.warehousesRepository.findOne({
      where: { warehouse_id: warehouseId },
    });
    if (!warehouse) {
      throw new NotFoundException(`Warehouse ${warehouseId} not found`);
    }
    return warehouse;
  }

  // ===== INVENTORY STOCK =====

  async getStockByItem(tenantId: string, itemId: string): Promise<any[]> {
    const query = `
      SELECT
        ist.*,
        ii.item_code,
        ii.item_name,
        w.warehouse_code,
        w.warehouse_name
      FROM inventory_stock ist
      JOIN inventory_items ii ON ist.item_id = ii.item_id
      JOIN warehouses w ON ist.warehouse_id = w.warehouse_id
      WHERE ist.tenant_id = $1 AND ist.item_id = $2
      ORDER BY w.warehouse_code
    `;

    return await this.dataSource.query(query, [tenantId, itemId]);
  }

  async getStockByWarehouse(tenantId: string, warehouseId: string): Promise<any[]> {
    const query = `
      SELECT
        ist.*,
        ii.item_code,
        ii.item_name,
        ii.base_unit,
        w.warehouse_code,
        w.warehouse_name
      FROM inventory_stock ist
      JOIN inventory_items ii ON ist.item_id = ii.item_id
      JOIN warehouses w ON ist.warehouse_id = w.warehouse_id
      WHERE ist.tenant_id = $1 AND ist.warehouse_id = $2
      AND ist.quantity_on_hand > 0
      ORDER BY ii.item_code
    `;

    return await this.dataSource.query(query, [tenantId, warehouseId]);
  }

  async getInventoryValuation(tenantId: string): Promise<any> {
    const query = `
      SELECT * FROM vw_inventory_valuation
      WHERE tenant_id = $1
      ORDER BY item_code, warehouse_code
    `;

    const items = await this.dataSource.query(query, [tenantId]);

    const summary = {
      total_quantity: items.reduce((sum, item) => sum + parseFloat(item.quantity_on_hand || 0), 0),
      total_value: items.reduce((sum, item) => sum + parseFloat(item.total_value || 0), 0),
      item_count: items.length,
      warehouse_count: [...new Set(items.map(item => item.warehouse_id))].length,
    };

    return {
      summary,
      items,
    };
  }

  async getInventoryReconciliation(tenantId: string): Promise<any> {
    const query = `
      SELECT * FROM vw_inventory_gl_reconciliation
      WHERE tenant_id = $1
    `;

    return await this.dataSource.query(query, [tenantId]);
  }

  async getInventoryTransactions(tenantId: string, filters?: any): Promise<any[]> {
    let query = `
      SELECT
        it.*,
        ii.item_code,
        ii.item_name,
        w.warehouse_code,
        w.warehouse_name
      FROM inventory_transactions it
      JOIN inventory_items ii ON it.item_id = ii.item_id
      JOIN warehouses w ON it.warehouse_id = w.warehouse_id
      WHERE it.tenant_id = $1
    `;

    const params: any[] = [tenantId];

    if (filters?.item_id) {
      params.push(filters.item_id);
      query += ` AND it.item_id = $${params.length}`;
    }

    if (filters?.transaction_type) {
      params.push(filters.transaction_type);
      query += ` AND it.transaction_type = $${params.length}`;
    }

    if (filters?.start_date) {
      params.push(filters.start_date);
      query += ` AND it.transaction_date >= $${params.length}`;
    }

    if (filters?.end_date) {
      params.push(filters.end_date);
      query += ` AND it.transaction_date <= $${params.length}`;
    }

    query += ` ORDER BY it.transaction_date DESC, it.created_at DESC LIMIT 100`;

    return await this.dataSource.query(query, params);
  }
}
