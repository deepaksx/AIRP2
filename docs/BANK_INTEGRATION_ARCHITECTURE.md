# Bank Statement Integration Architecture
## AIRP v2.0 - AI-Native Financial ERP

---

## 📊 Current Status

### ✅ What's Built (Demo Mode)
- **AI Reconciliation Engine** (Port 8002) - Matching algorithm with 3 stages:
  - Exact matching (amount + date)
  - Fuzzy matching (similarity scoring)
  - AI matching (complex pattern recognition)
- **Treasury Service** (Port 3005) - Bank account management
- **Database Schema** - `bank_accounts` and `bank_transactions` tables

### 🚧 What's Needed for Production
Bank statement **ingestion** layer to feed data into `bank_transactions` table

---

## 🏦 Production Bank Integration Methods

### Method 1: **Bank API Integration** (RECOMMENDED)
Direct connection to bank APIs for real-time data

#### UAE/GCC Banks with APIs:
- **Emirates NBD** - API Banking Platform
- **ADCB (Abu Dhabi Commercial Bank)** - Open Banking APIs
- **Mashreq Bank** - Mashreq API
- **Dubai Islamic Bank** - DIB Direct API
- **RAKBANK** - Corporate API Gateway

#### Implementation Architecture:
```
┌─────────────────┐
│   Bank API      │
│  (REST/SOAP)    │
└────────┬────────┘
         │ HTTPS/OAuth2
         ▼
┌─────────────────┐
│ Bank Feed       │
│ Connector       │ ← New microservice to build
│ Service         │
│ (NestJS/Python) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ bank_           │
│ transactions    │ ← PostgreSQL table (already exists)
│ table           │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ AI Recon        │
│ Service         │ ← Already built (Port 8002)
│ (Port 8002)     │
└─────────────────┘
```

#### Code Structure:
```typescript
// services/bank-feed-connector/src/integrations/

interface BankConnector {
  authenticate(): Promise<string>;
  fetchTransactions(accountId: string, fromDate: Date, toDate: Date): Promise<Transaction[]>;
  getBalance(accountId: string): Promise<Balance>;
}

class EmiratesNBDConnector implements BankConnector {
  constructor(
    private clientId: string,
    private clientSecret: string,
    private apiUrl: string
  ) {}

  async authenticate(): Promise<string> {
    // OAuth2 flow
    const response = await fetch(`${this.apiUrl}/oauth2/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: this.clientId,
        client_secret: this.clientSecret
      })
    });
    return response.json().access_token;
  }

  async fetchTransactions(accountId: string, fromDate: Date, toDate: Date) {
    const token = await this.authenticate();
    const response = await fetch(`${this.apiUrl}/accounts/${accountId}/transactions`, {
      headers: { 'Authorization': `Bearer ${token}` },
      params: { from: fromDate.toISOString(), to: toDate.toISOString() }
    });

    const transactions = await response.json();

    // Transform to AIRP format and save to bank_transactions table
    return transactions.map(tx => this.transformTransaction(tx));
  }

  private transformTransaction(bankTx: any): BankTransaction {
    return {
      transaction_id: uuid(),
      tenant_id: this.tenantId,
      bank_account_id: this.bankAccountId,
      transaction_date: bankTx.valueDate,
      value_date: bankTx.valueDate,
      description: bankTx.description,
      reference: bankTx.reference,
      debit_amount: bankTx.type === 'DEBIT' ? bankTx.amount : 0,
      credit_amount: bankTx.type === 'CREDIT' ? bankTx.amount : 0,
      balance: bankTx.balance,
      currency: bankTx.currency,
      reconciliation_status: 'unreconciled',
      metadata: { raw_bank_data: bankTx }
    };
  }
}
```

#### Database Extensions Needed:
```sql
-- Bank API Connections Configuration
CREATE TABLE bank_api_connections (
    connection_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    bank_account_id UUID NOT NULL REFERENCES bank_accounts(bank_account_id),
    bank_name VARCHAR(255) NOT NULL,
    api_provider VARCHAR(100) NOT NULL, -- 'enbd', 'adcb', 'mashreq', etc.
    connection_type VARCHAR(50) NOT NULL, -- 'api', 'sftp', 'manual'

    -- API Credentials (encrypted)
    client_id VARCHAR(255) ENCRYPTED,
    client_secret TEXT ENCRYPTED,
    api_url VARCHAR(500),

    -- Connection Status
    status VARCHAR(20) DEFAULT 'pending', -- pending, active, error, disabled
    last_sync_at TIMESTAMPTZ,
    last_sync_status VARCHAR(50),
    sync_frequency VARCHAR(20) DEFAULT 'daily', -- hourly, daily, weekly

    -- Error Tracking
    error_count INTEGER DEFAULT 0,
    last_error TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB
);

-- Bank Sync Log
CREATE TABLE bank_sync_log (
    sync_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    connection_id UUID NOT NULL REFERENCES bank_api_connections(connection_id),
    sync_started_at TIMESTAMPTZ DEFAULT NOW(),
    sync_completed_at TIMESTAMPTZ,
    status VARCHAR(50) NOT NULL, -- running, completed, failed
    transactions_fetched INTEGER DEFAULT 0,
    transactions_inserted INTEGER DEFAULT 0,
    transactions_skipped INTEGER DEFAULT 0,
    error_message TEXT,
    metadata JSONB
);
```

---

### Method 2: **Open Banking / PSD2** (for EU/UK banks)
Standardized APIs mandated by regulation

#### Providers:
- **Plaid** - North America, Europe
- **TrueLayer** - UK, Europe
- **Yapily** - Multi-country aggregator
- **Salt Edge** - Global coverage including Middle East

#### Implementation:
```typescript
// Using Plaid as an example
import { PlaidApi, Configuration, PlaidEnvironments } from 'plaid';

const plaidClient = new PlaidApi(
  new Configuration({
    basePath: PlaidEnvironments.production,
    baseOptions: {
      headers: {
        'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
        'PLAID-SECRET': process.env.PLAID_SECRET,
      },
    },
  })
);

// Link bank account
async function linkBankAccount(tenantId: string) {
  const tokenResponse = await plaidClient.linkTokenCreate({
    user: { client_user_id: tenantId },
    client_name: 'AIRP',
    products: ['transactions'],
    country_codes: ['AE', 'US', 'GB'],
    language: 'en',
  });

  return tokenResponse.data.link_token;
}

// Fetch transactions
async function syncTransactions(accessToken: string, startDate: string, endDate: string) {
  const response = await plaidClient.transactionsGet({
    access_token: accessToken,
    start_date: startDate,
    end_date: endDate,
  });

  // Insert into bank_transactions table
  await insertBankTransactions(response.data.transactions);
}
```

---

### Method 3: **SFTP/Secure File Transfer** (Traditional Banks)
Banks deliver daily statement files via SFTP

#### File Formats Supported:
- **MT940** (SWIFT standard) - Most common internationally
- **BAI2** (Bank Administration Institute) - US standard
- **CAMT.053** (ISO 20022 XML) - Modern standard
- **CSV/Excel** - Simple format

#### Implementation:
```typescript
import * as sftp from 'ssh2-sftp-client';
import { parseBAI2, parseMT940, parseCAMT053 } from './parsers';

async function fetchBankStatements() {
  const client = new sftp();

  await client.connect({
    host: 'sftp.bank.com',
    port: 22,
    username: process.env.BANK_SFTP_USER,
    password: process.env.BANK_SFTP_PASS,
    // or use SSH key
    privateKey: fs.readFileSync('/path/to/key')
  });

  // Download files
  const files = await client.list('/statements');

  for (const file of files) {
    const content = await client.get(`/statements/${file.name}`);

    let transactions;
    if (file.name.endsWith('.mt940')) {
      transactions = parseMT940(content);
    } else if (file.name.endsWith('.bai2')) {
      transactions = parseBAI2(content);
    } else if (file.name.endsWith('.xml')) {
      transactions = parseCAMT053(content);
    }

    // Insert into bank_transactions table
    await insertBankTransactions(transactions);

    // Archive processed file
    await client.rename(`/statements/${file.name}`, `/archive/${file.name}`);
  }

  await client.end();
}

// Schedule daily sync
cron.schedule('0 2 * * *', fetchBankStatements); // 2 AM daily
```

#### MT940 Parser Example:
```typescript
function parseMT940(content: string): BankTransaction[] {
  const transactions = [];
  const lines = content.split('\n');

  let currentTx: Partial<BankTransaction> = {};

  for (const line of lines) {
    if (line.startsWith(':61:')) {
      // Transaction line: :61:2501151501DR150000,00NCHK//REF123
      const match = line.match(/:61:(\d{6})(\d{4})(D|C)R?([\d,]+)/);
      if (match) {
        const [, date, valDate, dcMark, amount] = match;
        currentTx = {
          transaction_date: parseDate(date),
          value_date: parseDate(valDate),
          debit_amount: dcMark === 'D' ? parseFloat(amount.replace(',', '.')) : 0,
          credit_amount: dcMark === 'C' ? parseFloat(amount.replace(',', '.')) : 0,
        };
      }
    } else if (line.startsWith(':86:')) {
      // Description line
      currentTx.description = line.substring(4).trim();
      transactions.push(currentTx as BankTransaction);
      currentTx = {};
    }
  }

  return transactions;
}
```

---

### Method 4: **Manual Upload** (Fallback/Small Businesses)
User uploads CSV/Excel files via web interface

#### Implementation:
```typescript
// Frontend - File Upload Component
<input type="file" accept=".csv,.xlsx" onChange={handleFileUpload} />

async function handleFileUpload(event) {
  const file = event.target.files[0];
  const formData = new FormData();
  formData.append('file', file);
  formData.append('bank_account_id', selectedBankAccount);

  const response = await fetch('/api/treasury/upload-statement', {
    method: 'POST',
    body: formData
  });

  const result = await response.json();
  alert(`Imported ${result.transactions_count} transactions`);
}

// Backend - Parse CSV
import csv from 'csv-parser';

@Post('upload-statement')
@UseInterceptors(FileInterceptor('file'))
async uploadStatement(@UploadedFile() file: Express.Multer.File, @Body() body: any) {
  const transactions = [];

  const stream = Readable.from(file.buffer);
  stream
    .pipe(csv())
    .on('data', (row) => {
      transactions.push({
        transaction_id: uuid(),
        tenant_id: body.tenant_id,
        bank_account_id: body.bank_account_id,
        transaction_date: new Date(row['Date']),
        description: row['Description'],
        debit_amount: parseFloat(row['Debit']) || 0,
        credit_amount: parseFloat(row['Credit']) || 0,
        reference: row['Reference'],
        reconciliation_status: 'unreconciled'
      });
    })
    .on('end', async () => {
      await this.bankTransactionRepository.insert(transactions);
    });

  return { transactions_count: transactions.length };
}
```

---

## 🔄 Complete Data Flow

```
┌──────────────────────────────────────────────────────────┐
│                    DATA SOURCES                          │
├──────────────────────────────────────────────────────────┤
│  Bank APIs │ Open Banking │ SFTP │ Manual Upload        │
└─────┬────────────┬──────────┬──────────┬─────────────────┘
      │            │          │          │
      └────────────┴──────────┴──────────┘
                   │
                   ▼
      ┌───────────────────────┐
      │ Bank Feed Connector   │ ← NEW SERVICE TO BUILD
      │ Service (Port 3009)   │
      │ - Fetches data        │
      │ - Transforms format   │
      │ - Deduplicates        │
      └───────────┬───────────┘
                  │
                  ▼
      ┌───────────────────────┐
      │ bank_transactions     │ ← TABLE EXISTS
      │ PostgreSQL Table      │
      └───────────┬───────────┘
                  │
                  ▼
      ┌───────────────────────┐
      │ AI Reconciliation     │ ← SERVICE EXISTS (Port 8002)
      │ Engine                │
      │ - Exact match         │
      │ - Fuzzy match         │
      │ - AI match            │
      └───────────┬───────────┘
                  │
                  ▼
      ┌───────────────────────┐
      │ Matched Journal       │
      │ Entries               │
      │ (reconciled)          │
      └───────────────────────┘
```

---

## 📋 Recommended Implementation Plan

### Phase 1: Manual Upload (Immediate - 1 week)
✅ Fastest to implement
- Build CSV/Excel upload endpoint
- Create simple mapping UI
- Users can test reconciliation immediately

### Phase 2: SFTP Integration (Short-term - 2-3 weeks)
✅ Works with most UAE banks
- Build SFTP client
- Implement MT940/BAI2 parsers
- Schedule daily sync
- Error handling & retry logic

### Phase 3: Bank API Integration (Medium-term - 1-2 months)
✅ Best user experience
- Emirates NBD API integration first (largest in UAE)
- OAuth2 authentication flow
- Real-time transaction sync
- Webhook support for instant updates

### Phase 4: Open Banking Aggregators (Long-term - 2-3 months)
✅ Multi-bank support
- Integrate Plaid or Salt Edge
- Support 1000+ banks globally
- Single integration, many banks

---

## 🔒 Security Considerations

### API Credentials Storage:
```typescript
// Use encrypted columns in database
import * as crypto from 'crypto';

const algorithm = 'aes-256-gcm';
const key = process.env.ENCRYPTION_KEY; // 32-byte key

function encrypt(text: string): string {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(algorithm, key, iv);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag();
  return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}`;
}

function decrypt(encrypted: string): string {
  const [ivHex, authTagHex, encryptedData] = encrypted.split(':');
  const iv = Buffer.from(ivHex, 'hex');
  const authTag = Buffer.from(authTagHex, 'hex');
  const decipher = crypto.createDecipheriv(algorithm, key, iv);
  decipher.setAuthTag(authTag);
  let decrypted = decipher.update(encryptedData, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}
```

### Best Practices:
- ✅ Store bank credentials encrypted at rest
- ✅ Use OAuth2 instead of username/password when possible
- ✅ Implement IP whitelisting for bank API access
- ✅ Log all bank API calls for audit trail
- ✅ Implement rate limiting to avoid bank API throttling
- ✅ Use TLS 1.3 for all bank connections
- ✅ Rotate API keys every 90 days

---

## 💡 Current Workaround for Testing

**What you just tested:**
- Hardcoded bank transactions in `recon-demo.html`
- AI Reconciliation Engine processes them
- Matches with GL entries

**For production testing with real data:**
1. Export bank statement as CSV from your bank portal
2. Build simple CSV upload endpoint (Phase 1 above)
3. Upload → AI Recon processes it → See real matches!

---

## 📞 Bank Contact Points (UAE)

### Emirates NBD
- **API Portal:** https://developer.emiratesnbd.com
- **Contact:** apibanking@emiratesnbd.com

### ADCB
- **API Platform:** https://api.adcb.ae
- **Contact:** developer.support@adcb.com

### Mashreq Bank
- **API Gateway:** https://developer.mashreqbank.com
- **Contact:** api@mashreq.com

---

## Summary

**Current State:** AI Reconciliation Engine is fully functional, waiting for bank data to be fed in.

**Missing Piece:** Bank Feed Connector service to fetch statements from banks and insert into `bank_transactions` table.

**Fastest Path:** Build CSV upload (Phase 1) - can be done in 1 day, test with real data immediately!

**Best Long-term:** Bank API integration (Phase 3) - direct connection, real-time sync, best UX.
