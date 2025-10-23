import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import axios from 'axios';

/**
 * Context Auto-Update Worker
 * Automatically updates AI context for all master data entities when transactions occur
 */
@Injectable()
export class ContextUpdaterService {
  private readonly logger = new Logger(ContextUpdaterService.name);
  private readonly AI_CONTEXT_SERVICE_URL = process.env.AI_CONTEXT_SERVICE_URL || 'http://localhost:8007';
  private isRunning = false;

  constructor(
    @InjectDataSource()
    private dataSource: DataSource,
  ) {}

  // Run every 5 minutes to update contexts for entities that need it
  @Cron(CronExpression.EVERY_5_MINUTES)
  async handleContextUpdates() {
    if (this.isRunning) {
      this.logger.log('Context update already running, skipping...');
      return;
    }

    this.isRunning = true;
    this.logger.log('Starting context auto-update cycle...');

    try {
      await Promise.all([
        this.updateUserContexts(),
        this.updateVendorContexts(),
        this.updateCustomerContexts(),
        this.updateChartOfAccountsContexts(),
      ]);

      this.logger.log('Context auto-update cycle completed successfully');
    } catch (error) {
      this.logger.error('Context auto-update cycle failed:', error);
    } finally {
      this.isRunning = false;
    }
  }

  private async updateUserContexts() {
    // Find users that need context updates
    const users = await this.dataSource.query(`
      SELECT user_id, tenant_id, username, email, full_name, department, job_title
      FROM users
      WHERE (metadata->>'context_update_needed')::boolean = true
         OR ai_context_generated_at IS NULL
         OR ai_context_generated_at < NOW() - INTERVAL '30 days'
      LIMIT 10
    `);

    this.logger.log(`Updating context for ${users.length} users`);

    for (const user of users) {
      await this.generateContextForUser(user);
    }
  }

  private async generateContextForUser(user: any) {
    try {
      // Get user activity stats
      const stats = await this.dataSource.query(`
        SELECT
          COUNT(*) as total_activities,
          json_agg(DISTINCT activity_type) as activity_types,
          COUNT(DISTINCT CASE WHEN timestamp >= NOW() - INTERVAL '7 days' THEN activity_id END) as activities_week,
          json_object_agg(resource_type, COUNT(*)) FILTER (WHERE resource_type IS NOT NULL) as resource_breakdown
        FROM user_activity_log
        WHERE user_id = $1 AND timestamp >= NOW() - INTERVAL '90 days'
      `, [user.user_id]);

      const contextPayload = {
        entity_type: 'user',
        entity_id: user.user_id,
        entity_data: {
          ...user,
          activity_stats: stats[0],
        },
        tenant_id: user.tenant_id,
      };

      const response = await axios.post(
        `${this.AI_CONTEXT_SERVICE_URL}/generate-context`,
        contextPayload,
        { timeout: 30000 }
      );

      // Incremental update: merge keywords and append history
      await this.dataSource.query(`
        UPDATE users
        SET
          ai_context_history = append_context_history(
            ai_context_history,
            ai_context_summary,
            ai_context_keywords,
            ai_context_entities,
            ai_context_relationships,
            ai_context_generated_at,
            ai_context_model_version,
            10  -- Keep last 10 snapshots
          ),
          ai_context_summary = $1,
          ai_context_keywords = merge_context_keywords(ai_context_keywords, $2, 100),
          ai_context_entities = $3,
          ai_context_relationships = $4,
          ai_context_generated_at = NOW(),
          ai_context_model_version = $5,
          metadata = metadata - 'context_update_needed'
        WHERE user_id = $6
      `, [
        response.data.summary,
        response.data.keywords,
        JSON.stringify(response.data.entities),
        JSON.stringify(response.data.relationships),
        response.data.model_version || 'claude-3.5-sonnet',
        user.user_id,
      ]);

      this.logger.log(`Updated context for user ${user.username}`);
    } catch (error) {
      this.logger.error(`Failed to update context for user ${user.user_id}:`, error.message);
    }
  }

  private async updateVendorContexts() {
    const vendors = await this.dataSource.query(`
      SELECT vendor_id, tenant_id, vendor_code, vendor_name, vendor_type, payment_terms
      FROM vendors
      WHERE (metadata->>'context_update_needed')::boolean = true
         OR ai_context_generated_at IS NULL
         OR ai_context_generated_at < NOW() - INTERVAL '30 days'
      LIMIT 10
    `);

    this.logger.log(`Updating context for ${vendors.length} vendors`);

    for (const vendor of vendors) {
      await this.generateContextForVendor(vendor);
    }
  }

  private async generateContextForVendor(vendor: any) {
    try {
      // Get vendor transaction stats
      const stats = await this.dataSource.query(`
        SELECT
          COUNT(DISTINCT je.entry_id) as total_transactions,
          SUM(jel.credit_amount - jel.debit_amount) as total_payable,
          AVG(jel.credit_amount - jel.debit_amount) as avg_transaction_amount,
          MAX(je.entry_date) as last_transaction_date,
          json_agg(DISTINCT coa.account_code) as accounts_used
        FROM journal_entry_lines jel
        JOIN journal_entries je ON jel.entry_id = je.entry_id
        JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
        WHERE jel.dimension_1 = $1
          AND je.entry_date >= NOW() - INTERVAL '12 months'
      `, [vendor.vendor_id]);

      const contextPayload = {
        entity_type: 'vendor',
        entity_id: vendor.vendor_id,
        entity_data: {
          ...vendor,
          transaction_stats: stats[0],
        },
        tenant_id: vendor.tenant_id,
      };

      const response = await axios.post(
        `${this.AI_CONTEXT_SERVICE_URL}/generate-context`,
        contextPayload,
        { timeout: 30000 }
      );

      // Incremental update: merge keywords and append history
      await this.dataSource.query(`
        UPDATE vendors
        SET
          ai_context_history = append_context_history(
            ai_context_history,
            ai_context_summary,
            ai_context_keywords,
            ai_context_entities,
            ai_context_relationships,
            ai_context_generated_at,
            ai_context_model_version,
            10
          ),
          ai_context_summary = $1,
          ai_context_keywords = merge_context_keywords(ai_context_keywords, $2, 100),
          ai_context_entities = $3,
          ai_context_relationships = $4,
          ai_context_generated_at = NOW(),
          ai_context_model_version = $5,
          metadata = metadata - 'context_update_needed'
        WHERE vendor_id = $6
      `, [
        response.data.summary,
        response.data.keywords,
        JSON.stringify(response.data.entities),
        JSON.stringify(response.data.relationships),
        response.data.model_version || 'claude-3.5-sonnet',
        vendor.vendor_id,
      ]);

      this.logger.log(`Updated context for vendor ${vendor.vendor_name}`);
    } catch (error) {
      this.logger.error(`Failed to update context for vendor ${vendor.vendor_id}:`, error.message);
    }
  }

  private async updateCustomerContexts() {
    const customers = await this.dataSource.query(`
      SELECT customer_id, tenant_id, customer_code, customer_name, customer_type, payment_terms
      FROM customers
      WHERE (metadata->>'context_update_needed')::boolean = true
         OR ai_context_generated_at IS NULL
         OR ai_context_generated_at < NOW() - INTERVAL '30 days'
      LIMIT 10
    `);

    this.logger.log(`Updating context for ${customers.length} customers`);

    for (const customer of customers) {
      await this.generateContextForCustomer(customer);
    }
  }

  private async generateContextForCustomer(customer: any) {
    try {
      const stats = await this.dataSource.query(`
        SELECT
          COUNT(DISTINCT je.entry_id) as total_transactions,
          SUM(jel.debit_amount - jel.credit_amount) as total_receivable,
          AVG(jel.debit_amount - jel.credit_amount) as avg_transaction_amount,
          MAX(je.entry_date) as last_transaction_date,
          json_agg(DISTINCT coa.account_code) as accounts_used
        FROM journal_entry_lines jel
        JOIN journal_entries je ON jel.entry_id = je.entry_id
        JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
        WHERE jel.dimension_2 = $1
          AND je.entry_date >= NOW() - INTERVAL '12 months'
      `, [customer.customer_id]);

      const contextPayload = {
        entity_type: 'customer',
        entity_id: customer.customer_id,
        entity_data: {
          ...customer,
          transaction_stats: stats[0],
        },
        tenant_id: customer.tenant_id,
      };

      const response = await axios.post(
        `${this.AI_CONTEXT_SERVICE_URL}/generate-context`,
        contextPayload,
        { timeout: 30000 }
      );

      // Incremental update: merge keywords and append history
      await this.dataSource.query(`
        UPDATE customers
        SET
          ai_context_history = append_context_history(
            ai_context_history,
            ai_context_summary,
            ai_context_keywords,
            ai_context_entities,
            ai_context_relationships,
            ai_context_generated_at,
            ai_context_model_version,
            10
          ),
          ai_context_summary = $1,
          ai_context_keywords = merge_context_keywords(ai_context_keywords, $2, 100),
          ai_context_entities = $3,
          ai_context_relationships = $4,
          ai_context_generated_at = NOW(),
          ai_context_model_version = $5,
          metadata = metadata - 'context_update_needed'
        WHERE customer_id = $6
      `, [
        response.data.summary,
        response.data.keywords,
        JSON.stringify(response.data.entities),
        JSON.stringify(response.data.relationships),
        response.data.model_version || 'claude-3.5-sonnet',
        customer.customer_id,
      ]);

      this.logger.log(`Updated context for customer ${customer.customer_name}`);
    } catch (error) {
      this.logger.error(`Failed to update context for customer ${customer.customer_id}:`, error.message);
    }
  }

  private async updateChartOfAccountsContexts() {
    const accounts = await this.dataSource.query(`
      SELECT account_id, tenant_id, account_code, account_name, account_type, account_subtype
      FROM chart_of_accounts
      WHERE (metadata->>'context_update_needed')::boolean = true
         OR ai_context_generated_at IS NULL
         OR ai_context_generated_at < NOW() - INTERVAL '90 days'
      LIMIT 10
    `);

    this.logger.log(`Updating context for ${accounts.length} GL accounts`);

    for (const account of accounts) {
      await this.generateContextForAccount(account);
    }
  }

  private async generateContextForAccount(account: any) {
    try {
      const stats = await this.dataSource.query(`
        SELECT
          COUNT(*) as total_transactions,
          SUM(debit_amount) as total_debits,
          SUM(credit_amount) as total_credits,
          MAX(gb.period_end_date) as last_activity_date,
          json_agg(DISTINCT je.entry_type) as entry_types
        FROM gl_balances gb
        JOIN journal_entry_lines jel ON jel.account_id = gb.account_id
        JOIN journal_entries je ON jel.entry_id = je.entry_id
        WHERE gb.account_id = $1
          AND gb.fiscal_year >= EXTRACT(YEAR FROM NOW()) - 2
      `, [account.account_id]);

      const contextPayload = {
        entity_type: 'chart_of_account',
        entity_id: account.account_id,
        entity_data: {
          ...account,
          transaction_stats: stats[0],
        },
        tenant_id: account.tenant_id,
      };

      const response = await axios.post(
        `${this.AI_CONTEXT_SERVICE_URL}/generate-context`,
        contextPayload,
        { timeout: 30000 }
      );

      // Incremental update: merge keywords and append history
      await this.dataSource.query(`
        UPDATE chart_of_accounts
        SET
          ai_context_history = append_context_history(
            ai_context_history,
            ai_context_summary,
            ai_context_keywords,
            ai_context_entities,
            ai_context_relationships,
            ai_context_generated_at,
            ai_context_model_version,
            10
          ),
          ai_context_summary = $1,
          ai_context_keywords = merge_context_keywords(ai_context_keywords, $2, 100),
          ai_context_entities = $3,
          ai_context_relationships = $4,
          ai_context_generated_at = NOW(),
          ai_context_model_version = $5,
          metadata = metadata - 'context_update_needed'
        WHERE account_id = $6
      `, [
        response.data.summary,
        response.data.keywords,
        JSON.stringify(response.data.entities),
        JSON.stringify(response.data.relationships),
        response.data.model_version || 'claude-3.5-sonnet',
        account.account_id,
      ]);

      this.logger.log(`Updated context for account ${account.account_code} - ${account.account_name}`);
    } catch (error) {
      this.logger.error(`Failed to update context for account ${account.account_id}:`, error.message);
    }
  }

  // Manual trigger for immediate update
  async triggerImmediateUpdate() {
    this.logger.log('Manual context update triggered');
    await this.handleContextUpdates();
  }
}
