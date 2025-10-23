import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository, InjectDataSource } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { PurchaseOrder } from './entities/purchase-order.entity';

@Injectable()
export class ProcurementService {
  private readonly logger = new Logger(ProcurementService.name);

  constructor(
    @InjectRepository(PurchaseOrder)
    private poRepository: Repository<PurchaseOrder>,
    @InjectDataSource()
    private dataSource: DataSource,
  ) {}

  // ===== PURCHASE ORDERS =====

  async createPO(createPODto: any): Promise<any> {
    this.logger.log(`Creating Purchase Order: ${createPODto.po_number}`);

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Insert PO Header
      const poResult = await queryRunner.query(
        `INSERT INTO purchase_orders (
          tenant_id, po_number, po_date, vendor_id, requested_delivery_date,
          warehouse_id, currency, subtotal, tax_amount, total_amount, status,
          payment_terms, delivery_terms, notes, created_by
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        RETURNING po_id`,
        [
          createPODto.tenant_id,
          createPODto.po_number,
          createPODto.po_date,
          createPODto.vendor_id,
          createPODto.requested_delivery_date,
          createPODto.warehouse_id,
          createPODto.currency || 'AED',
          createPODto.subtotal,
          createPODto.tax_amount,
          createPODto.total_amount,
          createPODto.status || 'DRAFT',
          createPODto.payment_terms,
          createPODto.delivery_terms,
          createPODto.notes,
          createPODto.created_by,
        ]
      );

      const poId = poResult[0].po_id;

      // Insert PO Lines
      for (let i = 0; i < createPODto.lines.length; i++) {
        const line = createPODto.lines[i];
        await queryRunner.query(
          `INSERT INTO purchase_order_lines (
            tenant_id, po_id, line_number, item_id, description,
            ordered_quantity, received_quantity, outstanding_quantity,
            unit, unit_price, tax_rate, line_total, requested_delivery_date, line_status
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
          [
            createPODto.tenant_id,
            poId,
            i + 1,
            line.item_id,
            line.description,
            line.ordered_quantity,
            0,
            line.ordered_quantity,
            line.unit,
            line.unit_price,
            line.tax_rate || 0,
            line.line_total,
            line.requested_delivery_date,
            'OPEN',
          ]
        );
      }

      await queryRunner.commitTransaction();

      this.logger.log(`Purchase Order created successfully: ${createPODto.po_number}`);
      return { success: true, po_id: poId, po_number: createPODto.po_number };

    } catch (error) {
      await queryRunner.rollbackTransaction();
      this.logger.error(`Failed to create PO: ${error.message}`);
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async findAllPOs(tenantId: string, filters?: any): Promise<any[]> {
    let query = `
      SELECT
        po.*,
        v.vendor_name,
        v.vendor_code,
        w.warehouse_name,
        COUNT(pol.po_line_id) as line_count
      FROM purchase_orders po
      LEFT JOIN vendors v ON po.vendor_id = v.vendor_id
      LEFT JOIN warehouses w ON po.warehouse_id = w.warehouse_id
      LEFT JOIN purchase_order_lines pol ON po.po_id = pol.po_id
      WHERE po.tenant_id = $1
    `;

    const params: any[] = [tenantId];

    if (filters?.status) {
      params.push(filters.status);
      query += ` AND po.status = $${params.length}`;
    }

    query += ` GROUP BY po.po_id, v.vendor_name, v.vendor_code, w.warehouse_name`;
    query += ` ORDER BY po.po_date DESC, po.created_at DESC`;

    return await this.dataSource.query(query, params);
  }

  async findPOById(poId: string): Promise<any> {
    const po = await this.dataSource.query(
      `SELECT
        po.*,
        v.vendor_name,
        v.vendor_code,
        v.email as vendor_email,
        w.warehouse_name,
        w.warehouse_code
      FROM purchase_orders po
      LEFT JOIN vendors v ON po.vendor_id = v.vendor_id
      LEFT JOIN warehouses w ON po.warehouse_id = w.warehouse_id
      WHERE po.po_id = $1`,
      [poId]
    );

    if (!po || po.length === 0) {
      throw new NotFoundException(`Purchase Order ${poId} not found`);
    }

    const lines = await this.dataSource.query(
      `SELECT
        pol.*,
        ii.item_code,
        ii.item_name
      FROM purchase_order_lines pol
      JOIN inventory_items ii ON pol.item_id = ii.item_id
      WHERE pol.po_id = $1
      ORDER BY pol.line_number`,
      [poId]
    );

    return {
      ...po[0],
      lines,
    };
  }

  async postGoodsReceipt(grData: any): Promise<any> {
    this.logger.log(`Posting Goods Receipt: ${grData.gr_number}`);

    const result = await this.dataSource.query(
      `SELECT post_goods_receipt($1, $2, $3) as result`,
      [grData.tenant_id, grData.gr_id, grData.user_id]
    );

    const response = result[0].result;

    if (response.success) {
      this.logger.log(`Goods Receipt posted successfully: ${grData.gr_number}, Journal: ${response.journal_number}`);
    } else {
      this.logger.error(`Failed to post Goods Receipt: ${response.error}`);
    }

    return response;
  }

  async createGoodsReceipt(grData: any): Promise<any> {
    this.logger.log(`Creating Goods Receipt: ${grData.gr_number}`);

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Insert GR Header
      const grResult = await queryRunner.query(
        `INSERT INTO goods_receipts (
          tenant_id, gr_number, gr_date, posting_date, po_id, vendor_id,
          warehouse_id, delivery_note_number, delivery_date, currency,
          total_value, status, notes, created_by
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        RETURNING gr_id`,
        [
          grData.tenant_id,
          grData.gr_number,
          grData.gr_date,
          grData.posting_date,
          grData.po_id,
          grData.vendor_id,
          grData.warehouse_id,
          grData.delivery_note_number,
          grData.delivery_date,
          grData.currency || 'AED',
          grData.total_value,
          'DRAFT',
          grData.notes,
          grData.created_by,
        ]
      );

      const grId = grResult[0].gr_id;

      // Insert GR Lines
      for (let i = 0; i < grData.lines.length; i++) {
        const line = grData.lines[i];
        await queryRunner.query(
          `INSERT INTO goods_receipt_lines (
            tenant_id, gr_id, line_number, po_line_id, item_id, description,
            received_quantity, unit, unit_cost, line_value
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
          [
            grData.tenant_id,
            grId,
            i + 1,
            line.po_line_id,
            line.item_id,
            line.description,
            line.received_quantity,
            line.unit,
            line.unit_cost,
            line.line_value,
          ]
        );
      }

      await queryRunner.commitTransaction();

      // Now post the GR to create journal entries and update inventory
      const postResult = await this.postGoodsReceipt({
        tenant_id: grData.tenant_id,
        gr_id: grId,
        gr_number: grData.gr_number,
        user_id: grData.created_by,
      });

      this.logger.log(`Goods Receipt created and posted: ${grData.gr_number}`);
      return { success: true, gr_id: grId, gr_number: grData.gr_number, ...postResult };

    } catch (error) {
      await queryRunner.rollbackTransaction();
      this.logger.error(`Failed to create Goods Receipt: ${error.message}`);
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async getOutstandingPOs(tenantId: string): Promise<any[]> {
    return await this.dataSource.query(
      `SELECT * FROM vw_po_outstanding WHERE tenant_id = $1 ORDER BY po_date DESC`,
      [tenantId]
    );
  }
}
