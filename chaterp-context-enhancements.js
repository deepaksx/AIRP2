/**
 * AIRP v2.11.0 - ChatERP Context Display Enhancements
 * Rich formatting for AI-generated context metadata
 *
 * ADD THIS TO chaterp.html BEFORE THE CLOSING </script> TAG
 */

/**
 * Format vendor response with context
 */
function formatVendorWithContext(vendor) {
    let html = `
        <div class="context-enriched-card">
            <div class="card-header">
                <h5>🏢 ${vendor.vendor_name}</h5>
                <span class="badge badge-status">${vendor.status || 'active'}</span>
            </div>
    `;

    // AI Context Summary
    if (vendor.ai_context_summary) {
        html += `
            <div class="context-summary">
                <div class="context-icon">💡</div>
                <p class="summary-text">${vendor.ai_context_summary}</p>
            </div>
        `;
    }

    // Vendor Details
    html += `
        <div class="detail-grid">
            <div class="detail-item">
                <span class="label">Vendor Code</span>
                <span class="value">${vendor.vendor_code}</span>
            </div>
            <div class="detail-item">
                <span class="label">Payment Terms</span>
                <span class="value">${vendor.payment_terms || 'N/A'} days</span>
            </div>
    `;

    if (vendor.contact_email) {
        html += `
            <div class="detail-item">
                <span class="label">Contact</span>
                <span class="value">${vendor.contact_email}</span>
            </div>
        `;
    }

    html += `</div>`;

    // AI Context Keywords
    if (vendor.ai_context_keywords && vendor.ai_context_keywords.length > 0) {
        html += `
            <div class="context-keywords">
                <span class="keywords-label">Keywords:</span>
                <div class="keyword-chips">
        `;
        vendor.ai_context_keywords.slice(0, 6).forEach(keyword => {
            html += `<span class="keyword-chip">${keyword}</span>`;
        });
        html += `
                </div>
            </div>
        `;
    }

    // AI Context Relationships
    if (vendor.ai_context_relationships) {
        const rel = typeof vendor.ai_context_relationships === 'string'
            ? JSON.parse(vendor.ai_context_relationships)
            : vendor.ai_context_relationships;

        if (rel.typical_gl_accounts && rel.typical_gl_accounts.length > 0) {
            html += `
                <div class="context-relationships">
                    <div class="relationship-item">
                        <span class="rel-icon">📊</span>
                        <div class="rel-content">
                            <span class="rel-label">Typical GL Accounts</span>
                            <span class="rel-value">${rel.account_names ? rel.account_names.join(', ') : rel.typical_gl_accounts.join(', ')}</span>
                        </div>
                    </div>
            `;

            if (rel.estimated_monthly_spend) {
                html += `
                    <div class="relationship-item">
                        <span class="rel-icon">💰</span>
                        <div class="rel-content">
                            <span class="rel-label">Est. Monthly Spend</span>
                            <span class="rel-value">${capitalizeFirst(rel.estimated_monthly_spend)}</span>
                        </div>
                    </div>
                `;
            }

            if (rel.transaction_frequency) {
                html += `
                    <div class="relationship-item">
                        <span class="rel-icon">🔄</span>
                        <div class="rel-content">
                            <span class="rel-label">Transaction Frequency</span>
                            <span class="rel-value">${capitalizeFirst(rel.transaction_frequency)}</span>
                        </div>
                    </div>
                `;
            }

            html += `</div>`;
        }
    }

    html += `</div>`; // Close context-enriched-card

    return html;
}

/**
 * Format account response with context
 */
function formatAccountWithContext(account) {
    let html = `
        <div class="context-enriched-card">
            <div class="card-header">
                <h5>📊 ${account.account_code} - ${account.account_name}</h5>
                <span class="badge badge-${account.account_type.toLowerCase()}">${account.account_type}</span>
            </div>
    `;

    // AI Context Summary
    if (account.ai_context_summary) {
        html += `
            <div class="context-summary">
                <div class="context-icon">💡</div>
                <p class="summary-text">${account.ai_context_summary}</p>
            </div>
        `;
    }

    // Account Details
    html += `
        <div class="detail-grid">
            <div class="detail-item">
                <span class="label">Account Type</span>
                <span class="value">${account.account_type}</span>
            </div>
            <div class="detail-item">
                <span class="label">Normal Balance</span>
                <span class="value">${account.normal_balance}</span>
            </div>
    `;

    if (account.account_subtype) {
        html += `
            <div class="detail-item">
                <span class="label">Subtype</span>
                <span class="value">${account.account_subtype}</span>
            </div>
        `;
    }

    html += `</div>`;

    // AI Context Entities
    if (account.ai_context_entities) {
        const entities = typeof account.ai_context_entities === 'string'
            ? JSON.parse(account.ai_context_entities)
            : account.ai_context_entities;

        if (entities.usage_pattern) {
            html += `
                <div class="context-insights">
                    <div class="insight-item">
                        <span class="insight-icon">🔄</span>
                        <div class="insight-content">
                            <span class="insight-label">Usage Pattern</span>
                            <span class="insight-value">${capitalizeFirst(entities.usage_pattern.replace(/_/g, ' '))}</span>
                        </div>
                    </div>
            `;

            if (entities.materiality) {
                const materialityColor = entities.materiality === 'high' ? 'danger' : entities.materiality === 'medium' ? 'warning' : 'success';
                html += `
                    <div class="insight-item">
                        <span class="insight-icon">⚖️</span>
                        <div class="insight-content">
                            <span class="insight-label">Materiality</span>
                            <span class="insight-value text-${materialityColor}">${capitalizeFirst(entities.materiality)}</span>
                        </div>
                    </div>
                `;
            }

            html += `</div>`;
        }
    }

    // AI Context Keywords
    if (account.ai_context_keywords && account.ai_context_keywords.length > 0) {
        html += `
            <div class="context-keywords">
                <span class="keywords-label">Search Terms:</span>
                <div class="keyword-chips">
        `;
        account.ai_context_keywords.slice(0, 6).forEach(keyword => {
            html += `<span class="keyword-chip">${keyword}</span>`;
        });
        html += `
                </div>
            </div>
        `;
    }

    html += `</div>`; // Close context-enriched-card

    return html;
}

/**
 * Format list of vendors with context
 */
function formatVendorListWithContext(vendors) {
    if (!vendors || vendors.length === 0) {
        return '<p>No vendors found.</p>';
    }

    let html = `
        <div class="context-list-header">
            <h4>🏢 Vendors (${vendors.length})</h4>
        </div>
        <div class="context-list">
    `;

    vendors.forEach(vendor => {
        html += formatVendorWithContext(vendor);
    });

    html += `</div>`;

    return html;
}

/**
 * Format list of accounts with context
 */
function formatAccountListWithContext(accounts) {
    if (!accounts || accounts.length === 0) {
        return '<p>No accounts found.</p>';
    }

    let html = `
        <div class="context-list-header">
            <h4>📊 GL Accounts (${accounts.length})</h4>
        </div>
        <div class="context-list">
    `;

    accounts.forEach(account => {
        html += formatAccountWithContext(account);
    });

    html += `</div>`;

    return html;
}

/**
 * Helper function to capitalize first letter
 */
function capitalizeFirst(str) {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1);
}

/**
 * Enhanced showVendorBalances with context
 */
async function showVendorBalancesEnhanced() {
    try {
        addMessage('📊 Fetching vendor information with AI context...');

        const query = `
            SELECT v.vendor_id, v.vendor_code, v.vendor_name, v.payment_terms, v.contact_email, v.status,
                   v.ai_context_summary, v.ai_context_keywords, v.ai_context_entities, v.ai_context_relationships,
                   COALESCE(SUM(i.amount_outstanding), 0) as balance,
                   COUNT(i.invoice_id) as invoice_count
            FROM vendors v
            LEFT JOIN ap_invoices i ON v.vendor_id = i.vendor_id AND i.tenant_id=v.tenant_id
            WHERE v.tenant_id='${TENANT_ID}' AND v.status='active'
            GROUP BY v.vendor_id, v.vendor_code, v.vendor_name, v.payment_terms, v.contact_email, v.status,
                     v.ai_context_summary, v.ai_context_keywords, v.ai_context_entities, v.ai_context_relationships
            ORDER BY v.vendor_name
        `;

        const response = await fetch('http://localhost:3008/api/query', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ query, params: [] })
        });

        if (response.ok) {
            const vendors = await response.json();

            if (!vendors || vendors.length === 0) {
                addMessage('📋 No vendors found in the system.');
                return;
            }

            const html = formatVendorListWithContext(vendors);
            addMessage(html);
        } else {
            addMessage('❌ Failed to fetch vendor information.');
        }
    } catch (err) {
        addMessage(`❌ Error: ${err.message}`);
    }
}

/**
 * Enhanced account search with context
 */
async function searchAccountsByContextEnhanced(searchTerms) {
    try {
        addMessage(`🔍 Searching accounts for: "${searchTerms}"...`);

        // Convert search terms to array
        const termsArray = searchTerms.toLowerCase().split(/\s+/).filter(t => t.length > 0);

        const query = `
            SELECT account_id, account_code, account_name, account_type, account_subtype, normal_balance,
                   ai_context_summary, ai_context_keywords, ai_context_entities, ai_context_relationships
            FROM chart_of_accounts
            WHERE tenant_id = '${TENANT_ID}'
              AND status = 'active'
              AND (
                  ai_context_keywords && ARRAY[${termsArray.map(t => `'${t}'`).join(',')}]
                  OR LOWER(account_name) LIKE '%${searchTerms.toLowerCase()}%'
              )
            ORDER BY account_code
        `;

        const response = await fetch('http://localhost:3008/api/query', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ query, params: [] })
        });

        if (response.ok) {
            const accounts = await response.json();

            if (!accounts || accounts.length === 0) {
                addMessage(`ℹ️ No accounts found matching "${searchTerms}". Try different keywords.`);
                return;
            }

            const html = formatAccountListWithContext(accounts);
            addMessage(html);
        } else {
            addMessage('❌ Failed to search accounts.');
        }
    } catch (err) {
        addMessage(`❌ Error: ${err.message}`);
    }
}

// Export functions for use in main chaterp.html
window.formatVendorWithContext = formatVendorWithContext;
window.formatAccountWithContext = formatAccountWithContext;
window.formatVendorListWithContext = formatVendorListWithContext;
window.formatAccountListWithContext = formatAccountListWithContext;
window.showVendorBalancesEnhanced = showVendorBalancesEnhanced;
window.searchAccountsByContextEnhanced = searchAccountsByContextEnhanced;
