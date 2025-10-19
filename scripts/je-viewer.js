/**
 * Journal Entry Viewer Modal
 * Reusable component to display full journal entry details
 */

const JEViewer = {
    modal: null,

    init() {
        if (this.modal) return; // Already initialized

        // Create modal HTML
        const modalHTML = `
            <div id="je-viewer-modal" class="modal" style="display: none;">
                <div class="modal-backdrop" onclick="JEViewer.close()"></div>
                <div class="modal-content" style="max-width: 1200px; max-height: 90vh; overflow-y: auto;">
                    <div class="modal-header">
                        <h2 id="je-viewer-title">Journal Entry Details</h2>
                        <button class="modal-close" onclick="JEViewer.close()">&times;</button>
                    </div>
                    <div class="modal-body" id="je-viewer-body">
                        <div class="loading" style="text-align: center; padding: 40px;">
                            <div class="spinner"></div>
                            <div>Loading journal entry...</div>
                        </div>
                    </div>
                </div>
            </div>
        `;

        // Add modal to body
        const div = document.createElement('div');
        div.innerHTML = modalHTML;
        document.body.appendChild(div.firstElementChild);

        this.modal = document.getElementById('je-viewer-modal');

        // Add styles if not already present
        if (!document.getElementById('je-viewer-styles')) {
            const styles = document.createElement('style');
            styles.id = 'je-viewer-styles';
            styles.textContent = `
                .modal {
                    position: fixed;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    z-index: 9999;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .modal-backdrop {
                    position: absolute;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    background: rgba(0, 0, 0, 0.5);
                }
                .modal-content {
                    position: relative;
                    background: white;
                    border-radius: 8px;
                    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
                    width: 90%;
                    z-index: 1;
                }
                .modal-header {
                    padding: 20px 24px;
                    border-bottom: 1px solid #E5E5E5;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                }
                .modal-header h2 {
                    margin: 0;
                    font-size: 20px;
                    font-weight: 600;
                    color: #0A0A0A;
                }
                .modal-close {
                    background: none;
                    border: none;
                    font-size: 28px;
                    cursor: pointer;
                    color: #666;
                    width: 32px;
                    height: 32px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    border-radius: 4px;
                    transition: background 0.2s;
                }
                .modal-close:hover {
                    background: #F5F5F5;
                }
                .modal-body {
                    padding: 24px;
                }
                .je-detail-section {
                    margin-bottom: 24px;
                }
                .je-detail-section h3 {
                    font-size: 14px;
                    font-weight: 600;
                    color: #0A0A0A;
                    margin: 0 0 12px 0;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                }
                .je-info-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                    gap: 16px;
                    margin-bottom: 24px;
                }
                .je-info-item {
                    display: flex;
                    flex-direction: column;
                }
                .je-info-label {
                    font-size: 12px;
                    color: #666;
                    margin-bottom: 4px;
                    font-weight: 500;
                }
                .je-info-value {
                    font-size: 14px;
                    color: #0A0A0A;
                    font-weight: 400;
                }
                .je-lines-table {
                    width: 100%;
                    border-collapse: collapse;
                    margin-top: 12px;
                }
                .je-lines-table thead {
                    background: #F5F5F5;
                }
                .je-lines-table th {
                    padding: 12px;
                    text-align: left;
                    font-size: 12px;
                    font-weight: 600;
                    color: #0A0A0A;
                    border-bottom: 2px solid #D9D9D9;
                }
                .je-lines-table td {
                    padding: 12px;
                    font-size: 13px;
                    border-bottom: 1px solid #E5E5E5;
                }
                .je-lines-table .text-right {
                    text-align: right;
                }
                .je-lines-table .total-row {
                    background: #FAFAFA;
                    font-weight: 600;
                }
                .je-status-badge {
                    display: inline-block;
                    padding: 4px 12px;
                    border-radius: 12px;
                    font-size: 12px;
                    font-weight: 600;
                    text-transform: uppercase;
                }
                .je-status-posted {
                    background: #D5F5E3;
                    color: #0F5132;
                }
                .je-status-draft {
                    background: #FFF3CD;
                    color: #856404;
                }
                .je-status-reversed {
                    background: #F8D7DA;
                    color: #721C24;
                }
                .je-clickable {
                    color: #0070F3;
                    text-decoration: none;
                    cursor: pointer;
                    transition: color 0.2s;
                }
                .je-clickable:hover {
                    color: #0051C9;
                    text-decoration: underline;
                }
            `;
            document.head.appendChild(styles);
        }
    },

    async open(entryId, entryNumber) {
        this.init();

        // Show modal with loading state
        this.modal.style.display = 'flex';
        document.getElementById('je-viewer-title').textContent = `Journal Entry: ${entryNumber || entryId}`;
        document.getElementById('je-viewer-body').innerHTML = `
            <div class="loading" style="text-align: center; padding: 40px;">
                <div class="spinner"></div>
                <div>Loading journal entry details...</div>
            </div>
        `;

        try {
            // Fetch JE details
            const tenantId = window.TENANT_ID || '00000000-0000-0000-0000-000000000001';
            const apiUrl = window.API_URL || 'http://localhost:3008/api/query';

            const query = `
                SELECT
                    je.entry_id,
                    je.entry_number,
                    je.entry_date,
                    je.posting_date,
                    je.entry_type,
                    je.source_type,
                    je.description,
                    je.total_debit,
                    je.total_credit,
                    je.status,
                    je.created_at,
                    je.updated_at,
                    je.posted_by,
                    je.posted_at,
                    je.approved_by,
                    je.approved_at
                FROM journal_entries je
                WHERE je.entry_id = '${entryId}'
                AND je.tenant_id = '${tenantId}'
            `;

            const response = await fetch(apiUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ query })
            });

            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            const jeData = await response.json();

            if (!jeData || jeData.length === 0) {
                throw new Error('Journal entry not found');
            }

            const je = jeData[0];

            // Fetch JE lines
            const linesQuery = `
                SELECT
                    jel.line_id,
                    jel.line_number,
                    coa.account_code,
                    coa.account_name,
                    jel.description,
                    jel.debit_amount,
                    jel.credit_amount,
                    jel.metadata
                FROM journal_entry_lines jel
                JOIN chart_of_accounts coa ON jel.account_id = coa.account_id
                WHERE jel.entry_id = '${entryId}'
                ORDER BY jel.line_number
            `;

            const linesResponse = await fetch(apiUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ query: linesQuery })
            });

            if (!linesResponse.ok) throw new Error(`HTTP ${linesResponse.status}`);
            const lines = await linesResponse.json();

            // Render JE details
            this.render(je, lines);

        } catch (error) {
            document.getElementById('je-viewer-body').innerHTML = `
                <div style="text-align: center; padding: 40px; color: #BB0000;">
                    <div style="font-size: 48px; margin-bottom: 16px;">⚠️</div>
                    <div style="font-weight: 600; margin-bottom: 8px;">Failed to load journal entry</div>
                    <div style="font-size: 14px; color: #666;">${error.message}</div>
                </div>
            `;
        }
    },

    render(je, lines) {
        const statusClass = je.status === 'posted' ? 'je-status-posted' :
                           je.status === 'draft' ? 'je-status-draft' :
                           'je-status-reversed';

        const html = `
            <div class="je-detail-section">
                <h3>Entry Information</h3>
                <div class="je-info-grid">
                    <div class="je-info-item">
                        <div class="je-info-label">Entry Number</div>
                        <div class="je-info-value">${je.entry_number || '-'}</div>
                    </div>
                    <div class="je-info-item">
                        <div class="je-info-label">Entry Date</div>
                        <div class="je-info-value">${new Date(je.entry_date).toLocaleDateString('en-US', {year: 'numeric', month: 'long', day: 'numeric'})}</div>
                    </div>
                    <div class="je-info-item">
                        <div class="je-info-label">Posting Date</div>
                        <div class="je-info-value">${je.posting_date ? new Date(je.posting_date).toLocaleDateString('en-US', {year: 'numeric', month: 'long', day: 'numeric'}) : '-'}</div>
                    </div>
                    <div class="je-info-item">
                        <div class="je-info-label">Status</div>
                        <div class="je-info-value">
                            <span class="je-status-badge ${statusClass}">${je.status}</span>
                        </div>
                    </div>
                    <div class="je-info-item">
                        <div class="je-info-label">Entry Type</div>
                        <div class="je-info-value">${je.entry_type || '-'}</div>
                    </div>
                    <div class="je-info-item">
                        <div class="je-info-label">Source</div>
                        <div class="je-info-value">${je.source_type || '-'}</div>
                    </div>
                    <div class="je-info-item" style="grid-column: 1 / -1;">
                        <div class="je-info-label">Description</div>
                        <div class="je-info-value">${je.description || '-'}</div>
                    </div>
                </div>
            </div>

            <div class="je-detail-section">
                <h3>Journal Entry Lines</h3>
                <table class="je-lines-table">
                    <thead>
                        <tr>
                            <th style="width: 50px;">Line</th>
                            <th style="width: 100px;">Account</th>
                            <th>Account Name</th>
                            <th>Description</th>
                            <th style="width: 130px;" class="text-right">Debit (AED)</th>
                            <th style="width: 130px;" class="text-right">Credit (AED)</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${lines.map(line => {
                            const debit = parseFloat(line.debit_amount || 0);
                            const credit = parseFloat(line.credit_amount || 0);
                            return `
                                <tr>
                                    <td>${line.line_number || '-'}</td>
                                    <td class="text-bold">${line.account_code}</td>
                                    <td>${line.account_name}</td>
                                    <td>${line.description || '-'}</td>
                                    <td class="text-right ${debit > 0 ? 'amount-positive' : ''}">${debit > 0 ? debit.toLocaleString('en-AE', {minimumFractionDigits: 2}) : '-'}</td>
                                    <td class="text-right ${credit > 0 ? 'amount-negative' : ''}">${credit > 0 ? credit.toLocaleString('en-AE', {minimumFractionDigits: 2}) : '-'}</td>
                                </tr>
                            `;
                        }).join('')}
                        <tr class="total-row">
                            <td colspan="4"><strong>TOTAL</strong></td>
                            <td class="text-right amount-positive"><strong>${parseFloat(je.total_debit || 0).toLocaleString('en-AE', {minimumFractionDigits: 2})}</strong></td>
                            <td class="text-right amount-negative"><strong>${parseFloat(je.total_credit || 0).toLocaleString('en-AE', {minimumFractionDigits: 2})}</strong></td>
                        </tr>
                    </tbody>
                </table>
            </div>

            ${je.created_at || je.posted_at || je.approved_at ? `
                <div class="je-detail-section">
                    <h3>Audit Trail</h3>
                    <div class="je-info-grid">
                        ${je.created_at ? `
                            <div class="je-info-item">
                                <div class="je-info-label">Created At</div>
                                <div class="je-info-value">${new Date(je.created_at).toLocaleString('en-US', {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'})}</div>
                            </div>
                        ` : ''}
                        ${je.updated_at ? `
                            <div class="je-info-item">
                                <div class="je-info-label">Updated At</div>
                                <div class="je-info-value">${new Date(je.updated_at).toLocaleString('en-US', {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'})}</div>
                            </div>
                        ` : ''}
                        ${je.approved_at ? `
                            <div class="je-info-item">
                                <div class="je-info-label">Approved At</div>
                                <div class="je-info-value">${new Date(je.approved_at).toLocaleString('en-US', {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'})}</div>
                            </div>
                        ` : ''}
                        ${je.approved_by ? `
                            <div class="je-info-item">
                                <div class="je-info-label">Approved By</div>
                                <div class="je-info-value">${je.approved_by}</div>
                            </div>
                        ` : ''}
                        ${je.posted_at ? `
                            <div class="je-info-item">
                                <div class="je-info-label">Posted At</div>
                                <div class="je-info-value">${new Date(je.posted_at).toLocaleString('en-US', {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'})}</div>
                            </div>
                        ` : ''}
                        ${je.posted_by ? `
                            <div class="je-info-item">
                                <div class="je-info-label">Posted By</div>
                                <div class="je-info-value">${je.posted_by}</div>
                            </div>
                        ` : ''}
                    </div>
                </div>
            ` : ''}
        `;

        document.getElementById('je-viewer-body').innerHTML = html;
    },

    close() {
        if (this.modal) {
            this.modal.style.display = 'none';
        }
    }
};

// Make clickable JE numbers
function makeJEClickable(entryNumber, entryId) {
    return `<a href="#" class="je-clickable" onclick="event.preventDefault(); JEViewer.open('${entryId}', '${entryNumber}'); return false;">${entryNumber}</a>`;
}

// Initialize on page load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => JEViewer.init());
} else {
    JEViewer.init();
}
