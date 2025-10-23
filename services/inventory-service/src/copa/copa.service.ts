import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

@Injectable()
export class CopaService {
  private readonly logger = new Logger(CopaService.name);

  constructor(
    @InjectDataSource()
    private dataSource: DataSource,
  ) {}

  async getProfitabilityReport(tenantId: string, filters: any): Promise<any> {
    this.logger.log(`Getting COPA profitability report for tenant: ${tenantId}`);

    const {
      start_date,
      end_date,
      group_by = ['product_code'],  // Default grouping
      product_id,
      customer_id,
      sales_org,
      region,
      country,
    } = filters;

    // Build dynamic GROUP BY and SELECT clauses
    const groupByFields = group_by.map(field => `copa.${field}`).join(', ');
    const selectFields = group_by.map(field => `copa.${field}`).join(', ');

    let query = `
      SELECT
        ${selectFields},
        SUM(copa.revenue) as total_revenue,
        SUM(copa.sales_deductions) as total_deductions,
        SUM(copa.net_revenue) as total_net_revenue,
        SUM(copa.cogs) as total_cogs,
        SUM(copa.gross_margin) as total_gross_margin,
        CASE
          WHEN SUM(copa.revenue) > 0 THEN
            (SUM(copa.gross_margin) / SUM(copa.revenue) * 100)
          ELSE 0
        END as gross_margin_pct,
        SUM(copa.sales_quantity) as total_quantity,
        COUNT(*) as transaction_count
      FROM copa_actual_data copa
      WHERE copa.tenant_id = $1
    `;

    const params: any[] = [tenantId];

    if (start_date) {
      params.push(start_date);
      query += ` AND copa.posting_date >= $${params.length}`;
    }

    if (end_date) {
      params.push(end_date);
      query += ` AND copa.posting_date <= $${params.length}`;
    }

    if (product_id) {
      params.push(product_id);
      query += ` AND copa.product_id = $${params.length}`;
    }

    if (customer_id) {
      params.push(customer_id);
      query += ` AND copa.customer_id = $${params.length}`;
    }

    if (sales_org) {
      params.push(sales_org);
      query += ` AND copa.sales_org = $${params.length}`;
    }

    if (region) {
      params.push(region);
      query += ` AND copa.region = $${params.length}`;
    }

    if (country) {
      params.push(country);
      query += ` AND copa.country = $${params.length}`;
    }

    query += ` GROUP BY ${groupByFields}`;
    query += ` ORDER BY total_gross_margin DESC`;

    const data = await this.dataSource.query(query, params);

    // Calculate summary
    const summary = {
      total_revenue: data.reduce((sum, row) => sum + parseFloat(row.total_revenue || 0), 0),
      total_cogs: data.reduce((sum, row) => sum + parseFloat(row.total_cogs || 0), 0),
      total_margin: data.reduce((sum, row) => sum + parseFloat(row.total_gross_margin || 0), 0),
      total_quantity: data.reduce((sum, row) => sum + parseFloat(row.total_quantity || 0), 0),
      average_margin_pct: 0,
      row_count: data.length,
    };

    if (summary.total_revenue > 0) {
      summary.average_margin_pct = (summary.total_margin / summary.total_revenue) * 100;
    }

    return {
      summary,
      data,
      filters: {
        start_date,
        end_date,
        group_by,
      },
    };
  }

  async getProductProfitability(tenantId: string, filters: any): Promise<any> {
    this.logger.log(`Getting product profitability for tenant: ${tenantId}`);

    const query = `
      SELECT
        copa.product_id,
        copa.product_code,
        MAX(ii.item_name) as product_name,
        copa.product_group,
        SUM(copa.revenue) as total_revenue,
        SUM(copa.cogs) as total_cogs,
        SUM(copa.gross_margin) as total_margin,
        CASE
          WHEN SUM(copa.revenue) > 0 THEN
            (SUM(copa.gross_margin) / SUM(copa.revenue) * 100)
          ELSE 0
        END as margin_pct,
        SUM(copa.sales_quantity) as total_quantity,
        COUNT(*) as transaction_count
      FROM copa_actual_data copa
      LEFT JOIN inventory_items ii ON copa.product_id = ii.item_id
      WHERE copa.tenant_id = $1
      ${filters.start_date ? 'AND copa.posting_date >= $2' : ''}
      ${filters.end_date ? 'AND copa.posting_date <= $' + (filters.start_date ? '3' : '2') : ''}
      GROUP BY copa.product_id, copa.product_code, copa.product_group
      ORDER BY total_margin DESC
      LIMIT 50
    `;

    const params: any[] = [tenantId];
    if (filters.start_date) params.push(filters.start_date);
    if (filters.end_date) params.push(filters.end_date);

    return await this.dataSource.query(query, params);
  }

  async getCustomerProfitability(tenantId: string, filters: any): Promise<any> {
    this.logger.log(`Getting customer profitability for tenant: ${tenantId}`);

    const query = `
      SELECT
        copa.customer_id,
        copa.customer_code,
        MAX(c.customer_name) as customer_name,
        copa.customer_group,
        SUM(copa.revenue) as total_revenue,
        SUM(copa.cogs) as total_cogs,
        SUM(copa.gross_margin) as total_margin,
        CASE
          WHEN SUM(copa.revenue) > 0 THEN
            (SUM(copa.gross_margin) / SUM(copa.revenue) * 100)
          ELSE 0
        END as margin_pct,
        SUM(copa.sales_quantity) as total_quantity,
        COUNT(*) as transaction_count
      FROM copa_actual_data copa
      LEFT JOIN customers c ON copa.customer_id = c.customer_id
      WHERE copa.tenant_id = $1
      ${filters.start_date ? 'AND copa.posting_date >= $2' : ''}
      ${filters.end_date ? 'AND copa.posting_date <= $' + (filters.start_date ? '3' : '2') : ''}
      GROUP BY copa.customer_id, copa.customer_code, copa.customer_group
      ORDER BY total_margin DESC
      LIMIT 50
    `;

    const params: any[] = [tenantId];
    if (filters.start_date) params.push(filters.start_date);
    if (filters.end_date) params.push(filters.end_date);

    return await this.dataSource.query(query, params);
  }

  async getRegionProfitability(tenantId: string, filters: any): Promise<any> {
    this.logger.log(`Getting region profitability for tenant: ${tenantId}`);

    const query = `
      SELECT
        COALESCE(copa.region, 'Unassigned') as region,
        COALESCE(copa.country, 'Unassigned') as country,
        SUM(copa.revenue) as total_revenue,
        SUM(copa.cogs) as total_cogs,
        SUM(copa.gross_margin) as total_margin,
        CASE
          WHEN SUM(copa.revenue) > 0 THEN
            (SUM(copa.gross_margin) / SUM(copa.revenue) * 100)
          ELSE 0
        END as margin_pct,
        SUM(copa.sales_quantity) as total_quantity,
        COUNT(*) as transaction_count
      FROM copa_actual_data copa
      WHERE copa.tenant_id = $1
      ${filters.start_date ? 'AND copa.posting_date >= $2' : ''}
      ${filters.end_date ? 'AND copa.posting_date <= $' + (filters.start_date ? '3' : '2') : ''}
      GROUP BY copa.region, copa.country
      ORDER BY total_margin DESC
    `;

    const params: any[] = [tenantId];
    if (filters.start_date) params.push(filters.start_date);
    if (filters.end_date) params.push(filters.end_date);

    return await this.dataSource.query(query, params);
  }

  async getRevenueReconciliation(tenantId: string, fiscalYear: number, fiscalPeriod?: number): Promise<any> {
    this.logger.log(`Getting COPA revenue reconciliation for tenant: ${tenantId}, Year: ${fiscalYear}, Period: ${fiscalPeriod}`);

    let query = `
      SELECT * FROM vw_copa_revenue_reconciliation
      WHERE tenant_id = $1 AND fiscal_year = $2
    `;

    const params: any[] = [tenantId, fiscalYear];

    if (fiscalPeriod) {
      params.push(fiscalPeriod);
      query += ` AND fiscal_period = $${params.length}`;
    }

    query += ` ORDER BY fiscal_year DESC, fiscal_period DESC`;

    const reconciliation = await this.dataSource.query(query, params);

    return reconciliation.map(row => ({
      ...row,
      revenue_variance: parseFloat(row.gl_total_revenue || 0) - parseFloat(row.copa_total_revenue || 0),
      cogs_variance: parseFloat(row.gl_total_cogs || 0) - parseFloat(row.copa_total_cogs || 0),
      is_reconciled: Math.abs(parseFloat(row.gl_total_revenue || 0) - parseFloat(row.copa_total_revenue || 0)) < 0.01,
    }));
  }

  async getCopaDashboard(tenantId: string, filters: any): Promise<any> {
    this.logger.log(`Getting COPA dashboard for tenant: ${tenantId}`);

    const [
      topProducts,
      topCustomers,
      regionSummary,
      trendData,
    ] = await Promise.all([
      this.getProductProfitability(tenantId, { ...filters, limit: 10 }),
      this.getCustomerProfitability(tenantId, { ...filters, limit: 10 }),
      this.getRegionProfitability(tenantId, filters),
      this.getTrendData(tenantId, filters),
    ]);

    return {
      top_products: topProducts.slice(0, 10),
      top_customers: topCustomers.slice(0, 10),
      region_summary: regionSummary,
      trend_data: trendData,
    };
  }

  private async getTrendData(tenantId: string, filters: any): Promise<any[]> {
    const query = `
      SELECT
        copa.fiscal_year,
        copa.fiscal_period,
        TO_CHAR(DATE_TRUNC('month', copa.posting_date), 'YYYY-MM') as period_label,
        SUM(copa.revenue) as revenue,
        SUM(copa.cogs) as cogs,
        SUM(copa.gross_margin) as margin,
        CASE
          WHEN SUM(copa.revenue) > 0 THEN
            (SUM(copa.gross_margin) / SUM(copa.revenue) * 100)
          ELSE 0
        END as margin_pct
      FROM copa_actual_data copa
      WHERE copa.tenant_id = $1
      ${filters.start_date ? 'AND copa.posting_date >= $2' : ''}
      ${filters.end_date ? 'AND copa.posting_date <= $' + (filters.start_date ? '3' : '2') : ''}
      GROUP BY copa.fiscal_year, copa.fiscal_period, DATE_TRUNC('month', copa.posting_date)
      ORDER BY copa.fiscal_year, copa.fiscal_period
    `;

    const params: any[] = [tenantId];
    if (filters.start_date) params.push(filters.start_date);
    if (filters.end_date) params.push(filters.end_date);

    return await this.dataSource.query(query, params);
  }
}
