# AIRP v2.0 - COMPREHENSIVE TEST CHECKLIST

## TEST EXECUTION LOG
**Started:** [In Progress]
**Tester:** Claude Code (Systematic Testing)

---

## SECTION 1: BACKEND API ENDPOINTS

### 1.1 Ledger Writer Service (Port 3001)
- [ ] Service is running and healthy
- [ ] POST /journal-entries - Post new entry
- [ ] GET /chart-of-accounts - Get COA list (EXPECTED TO EXIST)
- [ ] GET /events - Get events list (EXPECTED TO EXIST)
- [ ] Service responds to health check

### 1.2 Reporting Service (Port 3008)
- [ ] Service is running and healthy
- [ ] GET /reports/trial-balance - Get trial balance
- [ ] Returns correct data structure
- [ ] All 11 accounts present

### 1.3 Event Store Service (Port 3001)
- [ ] GET /events/by-tenant/{id} - Get events by tenant
- [ ] Returns posted journal entries
- [ ] Event data structure is correct

---

## SECTION 2: FRONTEND PAGES - BASIC LOADING

### 2.1 Main Navigation (index.html)
- [ ] Page loads without errors
- [ ] No JavaScript errors in console
- [ ] CSS loads correctly
- [ ] Welcome screen displays
- [ ] Sidebar is visible
- [ ] Top navigation bar present

### 2.2 Area 1: Entities
- [ ] entities.html loads without errors
- [ ] Page structure renders
- [ ] Tabs are visible
- [ ] No console errors

### 2.3 Area 2: Master Data
- [ ] master-data.html loads without errors
- [ ] All 5 tabs visible
- [ ] Tab switching works
- [ ] No console errors

### 2.4 Area 3: Postings
- [ ] post-je.html loads without errors
- [ ] post-ap-invoice.html loads
- [ ] post-ar-invoice.html loads
- [ ] post-payment.html loads

### 2.5 Area 4: Registers & Ledgers
- [ ] je-register.html loads without errors
- [ ] gl-line-items.html loads
- [ ] vendor-ledger.html loads
- [ ] customer-ledger.html loads
- [ ] account-balances.html loads

### 2.6 Area 5: Financial Reports
- [ ] trial-balance.html loads without errors
- [ ] income-statement.html loads
- [ ] balance-sheet.html loads
- [ ] cash-flow-statement.html loads

### 2.7 Area 6: Database
- [ ] database-explorer.html loads without errors
- [ ] Table list renders
- [ ] No console errors

---

## SECTION 3: NAVIGATION FUNCTIONALITY

### 3.1 Main Navigation (index.html)
- [ ] Mode switcher Reports/AI Assistant works
- [ ] Sidebar items are clickable
- [ ] Click "1. Entities" → "Tenants" loads page
- [ ] Click "2. Master Data" → "Chart of Accounts" loads page
- [ ] Click "3. Postings" → "Journal Entry" loads page
- [ ] Click "4. Registers & Ledgers" → "JE Register" loads page
- [ ] Click "5. Financial Reports" → "Trial Balance" loads page
- [ ] Click "6. Database" → "Database Explorer" loads page
- [ ] iframe loads content correctly
- [ ] No 404 errors in network tab

### 3.2 Command Palette
- [ ] Press "/" opens command palette
- [ ] Press "Ctrl+K" opens command palette
- [ ] Search input is functional
- [ ] Results filter correctly
- [ ] Click result navigates to page
- [ ] Press "Esc" closes palette

### 3.3 Floating AI Assistant
- [ ] Bubble is visible
- [ ] Click opens side panel
- [ ] Panel has close button
- [ ] Click again toggles closed

---

## SECTION 4: DATA LOADING & DISPLAY

### 4.1 Entities Page
- [ ] API call is made to correct endpoint
- [ ] Data loads (or fallback works)
- [ ] Tenant "ACME Corporation" displays
- [ ] Tenant details are visible
- [ ] Status badge shows "active"
- [ ] Search box is functional

### 4.2 Master Data - Chart of Accounts
- [ ] API call is made on page load
- [ ] Stats cards populate with numbers
- [ ] Account table displays OR shows empty state
- [ ] If error, error message is clear
- [ ] Search functionality works (if data present)

### 4.3 Journal Entry Posting
- [ ] Form loads with all fields
- [ ] Entry date field present
- [ ] Account dropdown populates
- [ ] Can add line items
- [ ] Can remove line items
- [ ] Debit/Credit totals calculate
- [ ] Balance validation works
- [ ] Post button enables when balanced
- [ ] Can successfully post an entry
- [ ] Success message displays
- [ ] New entry gets ID and correlation ID

### 4.4 JE Register
- [ ] API call is made on page load
- [ ] Data loads OR error message shows
- [ ] If data present: table populates
- [ ] If data present: summary stats show
- [ ] Search functionality present
- [ ] Click entry shows details modal

### 4.5 GL Line Items
- [ ] API call is made on page load
- [ ] Account filter dropdown populates
- [ ] Date filters present
- [ ] Search box functional
- [ ] If data present: line items display
- [ ] Stats cards show totals
- [ ] Export CSV button present

### 4.6 Trial Balance
- [ ] API call is made on page load
- [ ] Data loads successfully
- [ ] All 11 accounts display
- [ ] Account grouping by type works
- [ ] Balance check panel shows debits/credits
- [ ] Balance status shows "Balanced" or "Unbalanced"
- [ ] Totals row calculates correctly
- [ ] Refresh button works
- [ ] Export buttons present

### 4.7 Database Explorer
- [ ] Table list displays 13 tables
- [ ] Click on "trial_balance" table
- [ ] API call is made
- [ ] Data displays in table
- [ ] Row count shows
- [ ] Export CSV button present
- [ ] Refresh button works
- [ ] Try other tables (chart_of_accounts, event_store)

---

## SECTION 5: FUNCTIONAL TESTING

### 5.1 Post New Journal Entry
- [ ] Navigate to post-je.html
- [ ] Enter test data:
  - Entry Date: Today
  - Line 1: DR 1000 (Cash) - 5000 AED
  - Line 2: CR 4000 (Revenue) - 5000 AED
- [ ] Verify debits = credits
- [ ] Click "Post Entry"
- [ ] Success message appears
- [ ] Entry ID returned
- [ ] No errors in console

### 5.2 Verify Entry in Trial Balance
- [ ] Navigate to trial-balance.html
- [ ] Click "Refresh" button
- [ ] Account 1000 balance increased by 5000
- [ ] Account 4000 balance increased by 5000
- [ ] Trial Balance still balanced
- [ ] Totals updated correctly

### 5.3 Search & Filter Testing
- [ ] In JE Register: Search for "rent"
- [ ] In GL Line Items: Filter by account
- [ ] In GL Line Items: Filter by date range
- [ ] In Master Data: Search for account code

### 5.4 Export Functionality
- [ ] Trial Balance: Click "Export CSV"
- [ ] GL Line Items: Click "Export CSV"
- [ ] Database Explorer: Click "Export CSV"
- [ ] Verify CSV downloads

---

## SECTION 6: ERROR HANDLING

### 6.1 API Errors
- [ ] If API returns 404, error message displays
- [ ] If API returns 500, error message displays
- [ ] Loading spinners show while waiting
- [ ] Empty states show when no data
- [ ] Network errors handled gracefully

### 6.2 Validation Errors
- [ ] Journal Entry: Unbalanced entry shows error
- [ ] Journal Entry: Missing required fields shows error
- [ ] Form validation works correctly

---

## SECTION 7: UI/UX TESTING

### 7.1 Responsive Design
- [ ] Pages render correctly at 1920x1080
- [ ] Sidebar is readable
- [ ] Tables don't overflow
- [ ] Buttons are clickable

### 7.2 Visual Elements
- [ ] Dark theme applied consistently
- [ ] Colors match (purple gradient)
- [ ] Icons display correctly
- [ ] Badges have correct colors
- [ ] Loading spinners animate

### 7.3 Interactions
- [ ] Hover effects work on buttons
- [ ] Click effects visible
- [ ] Dropdowns open/close
- [ ] Modals open/close
- [ ] Transitions are smooth

---

## SECTION 8: PERFORMANCE

### 8.1 Page Load Times
- [ ] index.html loads < 2 seconds
- [ ] trial-balance.html loads data < 3 seconds
- [ ] Navigation between pages is instant

### 8.2 API Response Times
- [ ] POST journal entry < 2 seconds
- [ ] GET trial balance < 2 seconds
- [ ] No hanging requests

---

## SECTION 9: BROWSER CONSOLE

### 9.1 Console Errors
- [ ] No JavaScript errors on any page
- [ ] No 404 errors for resources
- [ ] No CORS errors
- [ ] No API connection errors (except expected ones)

### 9.2 Network Tab
- [ ] All API calls visible
- [ ] Response codes correct (200, 404, 500)
- [ ] Response bodies contain expected data

---

## SECTION 10: TEST DATA VERIFICATION

### 10.1 Journal Entries
- [ ] 5 journal entries were posted
- [ ] Entry IDs exist
- [ ] Total debits = 106,000 AED
- [ ] Total credits = 106,000 AED

### 10.2 Account Balances
- [ ] 8 accounts affected
- [ ] Cash (1000) has transactions
- [ ] AR (1200) has transactions
- [ ] Revenue (4000) has transactions
- [ ] Expenses (5200, 5300, 5500, 5600) have transactions
- [ ] AP (2100) has transactions

---

## SUMMARY CHECKLIST

### Critical Tests (Must Pass)
- [ ] Journal Entry posting works
- [ ] Trial Balance displays data
- [ ] Navigation works
- [ ] No critical JavaScript errors

### Important Tests (Should Pass)
- [ ] Chart of Accounts loads
- [ ] JE Register displays entries
- [ ] GL Line Items displays
- [ ] Database Explorer works

### Nice to Have (Can be placeholders)
- [ ] AP/AR Invoice posting
- [ ] Income Statement
- [ ] Balance Sheet
- [ ] Cash Flow Statement

---

**Total Tests:** ~150 individual checks
**Estimated Time:** 30-45 minutes for thorough testing
**Priority:** Critical > Important > Nice to Have
