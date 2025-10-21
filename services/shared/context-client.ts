/**
 * AIRP v2.11.0 - AI Context Service Client
 * Shared library for calling AI Context Generator from NestJS services
 * Enables real-time context generation on record creation/update
 */

import axios, { AxiosInstance } from 'axios';

export interface GenerateContextRequest {
  entity_type: 'vendor' | 'customer' | 'account' | 'journal_entry' | 'ap_invoice' | 'ar_invoice';
  entity_id: string;
  tenant_id: string;
  entity_data: any;
}

export interface ContextResult {
  entity_type: string;
  entity_id: string;
  ai_context_summary: string;
  ai_context_keywords: string[];
  ai_context_entities: any;
  ai_context_relationships: any;
  ai_context_model_version: string;
}

export class ContextServiceClient {
  private client: AxiosInstance;
  private baseUrl: string;
  private enabled: boolean;

  constructor(baseUrl?: string) {
    this.baseUrl = baseUrl || process.env.CONTEXT_SERVICE_URL || 'http://localhost:8007';
    this.enabled = process.env.CONTEXT_GENERATION_ENABLED !== 'false';

    this.client = axios.create({
      baseURL: this.baseUrl,
      timeout: 30000, // 30 seconds for AI generation
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  /**
   * Generate context for a single entity (async, non-blocking)
   * Failures are logged but don't block the main operation
   */
  async generateContextAsync(request: GenerateContextRequest): Promise<void> {
    if (!this.enabled) {
      console.log(`[Context] Context generation disabled, skipping ${request.entity_type} ${request.entity_id}`);
      return;
    }

    // Fire and forget - don't await
    this.generateContext(request)
      .then(() => {
        console.log(`[Context] ✅ Generated context for ${request.entity_type} ${request.entity_id}`);
      })
      .catch((error) => {
        console.error(`[Context] ❌ Failed to generate context for ${request.entity_type} ${request.entity_id}:`, error.message);
        // Don't throw - context generation failure shouldn't break main operation
      });
  }

  /**
   * Generate context for a single entity (blocking)
   * Use only when you need to wait for context generation
   */
  async generateContext(request: GenerateContextRequest): Promise<ContextResult> {
    try {
      const response = await this.client.post<ContextResult>('/generate-context', request);
      return response.data;
    } catch (error: any) {
      if (error.response) {
        throw new Error(`Context service error: ${error.response.status} - ${JSON.stringify(error.response.data)}`);
      } else if (error.request) {
        throw new Error('Context service unavailable - no response received');
      } else {
        throw new Error(`Context service error: ${error.message}`);
      }
    }
  }

  /**
   * Check if context service is available
   */
  async healthCheck(): Promise<boolean> {
    try {
      const response = await this.client.get('/health');
      return response.data.status === 'healthy' && response.data.ai_enabled === true;
    } catch {
      return false;
    }
  }

  /**
   * Batch generate context for multiple entities
   */
  async batchGenerate(
    entity_type: string,
    tenant_id: string,
    limit: number = 100
  ): Promise<{
    total_processed: number;
    successful: number;
    failed: number;
    coverage_percentage: number;
  }> {
    const response = await this.client.post('/batch-generate', {
      entity_type,
      tenant_id,
      limit,
    });
    return response.data;
  }

  /**
   * Get context coverage statistics
   */
  async getStats(tenant_id: string): Promise<any> {
    const response = await this.client.get('/context-stats', {
      params: { tenant_id },
    });
    return response.data;
  }
}

/**
 * Singleton instance for easy access
 */
export const contextService = new ContextServiceClient();

/**
 * Helper function to generate context for vendor
 */
export async function generateVendorContext(vendor: any): Promise<void> {
  if (!vendor.vendor_id || !vendor.tenant_id) {
    console.warn('[Context] Missing vendor_id or tenant_id, skipping context generation');
    return;
  }

  await contextService.generateContextAsync({
    entity_type: 'vendor',
    entity_id: vendor.vendor_id,
    tenant_id: vendor.tenant_id,
    entity_data: {
      vendor_code: vendor.vendor_code,
      vendor_name: vendor.vendor_name,
      payment_terms: vendor.payment_terms,
      contact_email: vendor.contact_email,
      status: vendor.status,
    },
  });
}

/**
 * Helper function to generate context for customer
 */
export async function generateCustomerContext(customer: any): Promise<void> {
  if (!customer.customer_id || !customer.tenant_id) {
    console.warn('[Context] Missing customer_id or tenant_id, skipping context generation');
    return;
  }

  await contextService.generateContextAsync({
    entity_type: 'customer',
    entity_id: customer.customer_id,
    tenant_id: customer.tenant_id,
    entity_data: {
      customer_code: customer.customer_code,
      customer_name: customer.customer_name,
      payment_terms: customer.payment_terms,
      contact_email: customer.contact_email,
      status: customer.status,
    },
  });
}

/**
 * Helper function to generate context for GL account
 */
export async function generateAccountContext(account: any): Promise<void> {
  if (!account.account_id || !account.tenant_id) {
    console.warn('[Context] Missing account_id or tenant_id, skipping context generation');
    return;
  }

  await contextService.generateContextAsync({
    entity_type: 'account',
    entity_id: account.account_id,
    tenant_id: account.tenant_id,
    entity_data: {
      account_code: account.account_code,
      account_name: account.account_name,
      account_type: account.account_type,
      account_subtype: account.account_subtype,
      normal_balance: account.normal_balance,
      status: account.status,
    },
  });
}

/**
 * Helper function to generate context for journal entry
 */
export async function generateJournalEntryContext(entry: any, lines: any[]): Promise<void> {
  if (!entry.entry_id || !entry.tenant_id) {
    console.warn('[Context] Missing entry_id or tenant_id, skipping context generation');
    return;
  }

  await contextService.generateContextAsync({
    entity_type: 'journal_entry',
    entity_id: entry.entry_id,
    tenant_id: entry.tenant_id,
    entity_data: {
      entry_number: entry.entry_number,
      entry_date: entry.entry_date,
      entry_type: entry.entry_type,
      description: entry.description,
      total_debit: entry.total_debit,
      total_credit: entry.total_credit,
      status: entry.status,
      lines: lines,
    },
  });
}

/**
 * Helper function to generate context for AP invoice
 */
export async function generateAPInvoiceContext(invoice: any): Promise<void> {
  if (!invoice.invoice_id || !invoice.tenant_id) {
    console.warn('[Context] Missing invoice_id or tenant_id, skipping context generation');
    return;
  }

  await contextService.generateContextAsync({
    entity_type: 'ap_invoice',
    entity_id: invoice.invoice_id,
    tenant_id: invoice.tenant_id,
    entity_data: {
      invoice_number: invoice.invoice_number,
      vendor_id: invoice.vendor_id,
      invoice_date: invoice.invoice_date,
      due_date: invoice.due_date,
      total_amount: invoice.total_amount,
      description: invoice.description,
      status: invoice.status,
    },
  });
}

/**
 * Helper function to generate context for AR invoice
 */
export async function generateARInvoiceContext(invoice: any): Promise<void> {
  if (!invoice.invoice_id || !invoice.tenant_id) {
    console.warn('[Context] Missing invoice_id or tenant_id, skipping context generation');
    return;
  }

  await contextService.generateContextAsync({
    entity_type: 'ar_invoice',
    entity_id: invoice.invoice_id,
    tenant_id: invoice.tenant_id,
    entity_data: {
      invoice_number: invoice.invoice_number,
      customer_id: invoice.customer_id,
      invoice_date: invoice.invoice_date,
      due_date: invoice.due_date,
      total_amount: invoice.total_amount,
      description: invoice.description,
      status: invoice.status,
    },
  });
}
