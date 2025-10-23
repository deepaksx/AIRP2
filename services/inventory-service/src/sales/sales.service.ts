import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository, InjectDataSource } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { SalesOrder } from './entities/sales-order.entity';

@Injectable()
export class SalesService {
  private readonly logger = new Logger(SalesService.name);

  constructor(
    @InjectRepository(SalesOrder)
    private soRepository: Repository<SalesOrder>,
    @InjectDataSource()
    private dataSource: DataSource,
  ) {}

  // ===== SALES ORDERS =====

  async createSO(createSODto: any): Promise<any> {
    this.logger.log(`Creating Sales Order: ${createSODto.so_number}`);

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Insert SO Header
      const soResult = await queryRunner.query(
        `INSERT INTO sales_orders (
          tenant_id, so_number, so_date, customer_id, requested_delivery_date,
          warehouse_id, ship_to_name, ship_to_address, ship_to_city, ship_to_country,
          currency, subtotal, tax_amount, total_amount, status,
          payment_terms, delivery_terms, notes, created_by,
          copa_sales_org, copa_distribution_channel, copa_division,
          copa_sales_office, copa_sales_group, copa_region, copa_country
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26)
        RETURNING so_id`,
        [
          createSODto.tenant_id,
          createSODto.so_number,
          createSODto.so_date,
          createSODto.customer_id,
          createSODto.requested_delivery_date,
          createSODto.warehouse_id,
          createSODto.ship_to_name,
          createSODto.ship_to_address,
          createSODto.ship_to_city,
          createSODto.ship_to_country,
          createSODto.currency || 'AED',
          createSODto.subtotal,
          createSODto.tax_amount,
          createSODto.total_amount,
          createSODto.status || 'DRAFT',
          createSODto.payment_terms,
          createSODto.delivery_terms,
          createSODto.notes,
          createSODto.created_by,
          createSODto.copa_sales_org,
          createSODto.copa_distribution_channel,
          createSODto.copa_division,
          createSODto.copa_sales_office,
          createSODto.copa_sales_group,
          createSODto.copa_region,
          createSODto.copa_country,
        ]
      );

      const soId = soResult[0].so_id;

      // Insert SO Lines
      for (let i = 0; i < createSODto.lines.length; i++) {
        const line = createSODto.lines[i];
        await queryRunner.query(
          `INSERT INTO sales_order_lines (
            tenant_id, so_id, line_number, item_id, description,
            ordered_quantity, delivered_quantity, outstanding_quantity,
            unit, unit_price, cost_price, tax_rate, line_total,
            requested_delivery_date, line_status
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
          [
            createSODto.tenant_id,
            soId,
            i + 1,
            line.item_id,
            line.description,
            line.ordered_quantity,
            0,
            line.ordered_quantity,
            line.unit,
            line.unit_price,
            line.cost_price || 0,
            line.tax_rate || 0,
            line.line_total,
            line.requested_delivery_date,
            'OPEN',
          ]
        );
      }

      await queryRunner.commitTransaction();

      this.logger.log(`Sales Order created successfully: ${createSODto.so_number}`);
      return { success: true, so_id: soId, so_number: createSODto.so_number };

    } catch (error) {
      await queryRunner.rollbackTransaction();
      this.logger.error(`Failed to create SO: ${error.message}`);
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async findAllSOs(tenantId: string, filters?: any): Promise<any[]> {
    let query = `
      SELECT
        so.*,
        c.customer_name,
        c.customer_code,
        w.warehouse_name,
        COUNT(sol.so_line_id) as line_count
      FROM sales_orders so
      LEFT JOIN customers c ON so.customer_id = c.customer_id
      LEFT JOIN warehouses w ON so.warehouse_id = w.warehouse_id
      LEFT JOIN sales_order_lines sol ON so.so_id = sol.so_id
      WHERE so.tenant_id = $1
    `;

    const params: any[] = [tenantId];

    if (filters?.status) {
      params.push(filters.status);
      query += ` AND so.status = $${params.length}`;
    }

    query += ` GROUP BY so.so_id, c.customer_name, c.customer_code, w.warehouse_name`;
    query += ` ORDER BY so.so_date DESC, so.created_at DESC`;

    return await this.dataSource.query(query, params);
  }

  async findSOById(soId: string): Promise<any> {
    const so = await this.dataSource.query(
      `SELECT
        so.*,
        c.customer_name,
        c.customer_code,
        c.email as customer_email,
        w.warehouse_name,
        w.warehouse_code
      FROM sales_orders so
      LEFT JOIN customers c ON so.customer_id = c.customer_id
      LEFT JOIN warehouses w ON so.warehouse_id = w.warehouse_id
      WHERE so.so_id = $1`,
      [soId]
    );

    if (!so || so.length === 0) {
      throw new NotFoundException(`Sales Order ${soId} not found`);
    }

    const lines = await this.dataSource.query(
      `SELECT
        sol.*,
        ii.item_code,
        ii.item_name
      FROM sales_order_lines sol
      JOIN inventory_items ii ON sol.item_id = ii.item_id
      WHERE sol.so_id = $1
      ORDER BY sol.line_number`,
      [soId]
    );

    return {
      ...so[0],
      lines,
    };
  }

  async createSalesDelivery(deliveryData: any): Promise<any> {
    this.logger.log(`Creating Sales Delivery: ${deliveryData.delivery_number}`);

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Insert Delivery Header
      const deliveryResult = await queryRunner.query(
        `INSERT INTO sales_deliveries (
          tenant_id, delivery_number, delivery_date, posting_date, so_id,
          customer_id, warehouse_id, ship_to_name, ship_to_address,
          tracking_number, carrier, currency, status, notes, created_by
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        RETURNING delivery_id`,
        [
          deliveryData.tenant_id,
          deliveryData.delivery_number,
          deliveryData.delivery_date,
          deliveryData.posting_date,
          deliveryData.so_id,
          deliveryData.customer_id,
          deliveryData.warehouse_id,
          deliveryData.ship_to_name,
          deliveryData.ship_to_address,
          deliveryData.tracking_number,
          deliveryData.carrier,
          deliveryData.currency || 'AED',
          'DRAFT',
          deliveryData.notes,
          deliveryData.created_by,
        ]
      );

      const deliveryId = deliveryResult[0].delivery_id;

      // Insert Delivery Lines
      for (let i = 0; i < deliveryData.lines.length; i++) {
        const line = deliveryData.lines[i];
        await queryRunner.query(
          `INSERT INTO sales_delivery_lines (
            tenant_id, delivery_id, line_number, so_line_id, item_id, description,
            delivered_quantity, unit, unit_price, unit_cost,
            line_revenue, line_cogs, line_margin
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
          [
            deliveryData.tenant_id,
            deliveryId,
            i + 1,
            line.so_line_id,
            line.item_id,
            line.description,
            line.delivered_quantity,
            line.unit,
            line.unit_price,
            line.unit_cost,
            line.line_revenue,
            line.line_cogs,
            line.line_margin,
          ]
        );
      }

      await queryRunner.commitTransaction();

      // Now post the delivery to create journal entries, update inventory, and create COPA records
      const postResult = await this.postSalesDelivery({
        tenant_id: deliveryData.tenant_id,
        delivery_id: deliveryId,
        delivery_number: deliveryData.delivery_number,
        user_id: deliveryData.created_by,
      });

      this.logger.log(`Sales Delivery created and posted: ${deliveryData.delivery_number}`);
      return { success: true, delivery_id: deliveryId, delivery_number: deliveryData.delivery_number, ...postResult };

    } catch (error) {
      await queryRunner.rollbackTransaction();
      this.logger.error(`Failed to create Sales Delivery: ${error.message}`);
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async postSalesDelivery(deliveryData: any): Promise<any> {
    this.logger.log(`Posting Sales Delivery: ${deliveryData.delivery_number}`);

    const result = await this.dataSource.query(
      `SELECT post_sales_delivery($1, $2, $3) as result`,
      [deliveryData.tenant_id, deliveryData.delivery_id, deliveryData.user_id]
    );

    const response = result[0].result;

    if (response.success) {
      this.logger.log(`Sales Delivery posted successfully: ${deliveryData.delivery_number}, Journal: ${response.journal_number}, COPA Records: ${response.copa_records_created}`);
    } else {
      this.logger.error(`Failed to post Sales Delivery: ${response.error}`);
    }

    return response;
  }

  async getOutstandingSOs(tenantId: string): Promise<any[]> {
    return await this.dataSource.query(
      `SELECT * FROM vw_so_outstanding WHERE tenant_id = $1 ORDER BY so_date DESC`,
      [tenantId]
    );
  }
}
