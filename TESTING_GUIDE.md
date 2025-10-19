# AIRP v2.0 - Manual Testing Guide

## Quick Start
🌐 **Application URL:** http://localhost:5000

---

## Test Data Summary
✅ **5 Journal Entries** posted with test transactions
✅ **106,000 AED** total transaction value
✅ **10 GL line items** created
✅ **8 accounts** affected with balances

---

## Testing Checklist

### 1. 🏛️ ENTITIES MANAGEMENT
**URL:** Click "1. Entities" → "Tenants"

**What to Test:**
- [ ] Page loads without errors
- [ ] ACME Corporation tenant displays
- [ ] Tenant details visible (code, legal name, currency, timezone)
- [ ] Status badge shows "active" in green
- [ ] Search box is present
- [ ] "Add Tenant" button visible

**Expected Result:** ✅ Should show ACME Corporation with all details

---

### 2. 📑 MASTER DATA - Chart of Accounts
**URL:** Click "2. Master Data" → "Chart of Accounts"

**What to Test:**
- [ ] Page loads without errors
- [ ] Stats cards show: Total Accounts, Active, Asset Accounts, Liability Accounts
- [ ] Empty state message displays (API not implemented yet)
- [ ] Search box functional
- [ ] "Add Account" button present
- [ ] All 5 tabs visible (COA, Vendors, Customers, Banks, Products)

**Expected Result:** ⚠️ Shows empty state with message (API needs implementation)

**Note:** COA API endpoint needs to be added to see actual data

---

### 3. ✍️ POSTINGS - Journal Entry
**URL:** Click "3. Postings" → "Journal Entry"

**What to Test:**
- [ ] Page loads without errors
- [ ] Entry date defaults to today
- [ ] Account dropdown populated (if API works)
- [ ] Can add line items with "Add Line" button
- [ ] Can remove lines
- [ ] Debit/Credit totals calculated automatically
- [ ] "Post Entry" button enabled when balanced
- [ ] Try posting a simple entry:
  - DR: 1000 Cash - 1000 AED
  - CR: 4000 Revenue - 1000 AED

**Expected Result:** ✅ Should successfully post and show success message

---

### 4. 📋 REGISTERS - JE Register
**URL:** Click "4. Registers & Ledgers" → "JE Register"

**What to Test:**
- [ ] Page loads without errors
- [ ] Summary cards show entry count
- [ ] Search box present
- [ ] Table structure visible

**Expected Result:** ❌ Will show loading spinner then error (API endpoint missing)

**Known Issue:** Event Store GET API not implemented yet
- Expected endpoint: `GET /events/by-tenant/{tenant_id}`
- Current status: 404 Not Found

---

### 5. 📖 REGISTERS - GL Line Items
**URL:** Click "4. Registers & Ledgers" → "GL Line Items"

**What to Test:**
- [ ] Page loads without errors
- [ ] Filter dropdowns present (Account, Date From, Date To)
- [ ] Search box for description
- [ ] Export CSV button
- [ ] Refresh button
- [ ] Stats cards (Total Lines, Total Debits, Total Credits, Net Balance)

**Expected Result:** ❌ Will show loading then error (API endpoint missing)

**Known Issue:** Same as JE Register - Event Store API needed

---

### 6. ⚖️ FINANCIAL REPORTS - Trial Balance
**URL:** Click "5. Financial Reports" → "Trial Balance"

**What to Test:**
- [ ] Page loads without errors
- [ ] Report title shows "ACME Corporation"
- [ ] "As of" date displays
- [ ] Balance check panel shows Total Debits, Total Credits
- [ ] Balance status shows "✓ Balanced" in green
- [ ] All 11 accounts listed in table
- [ ] Accounts grouped by type (Asset, Liability, Revenue, Expense)
- [ ] Debit amounts shown in green
- [ ] Credit amounts shown in red
- [ ] Total row at bottom matches balance check

**Expected Result:** ✅ **FULLY WORKING** - Should display complete trial balance

**Verify:**
- Total Debits = Total Credits (balanced)
- All account types represented
- Export buttons present

---

### 7. 🗄️ DATABASE EXPLORER
**URL:** Click "6. Database" → "Database Explorer"

**What to Test:**
- [ ] Page loads without errors
- [ ] Sidebar lists 13 tables with icons
- [ ] Welcome message displays initially
- [ ] Click on "trial_balance" table
- [ ] Data loads and displays in table
- [ ] Row count shows at bottom
- [ ] Export CSV button works
- [ ] Refresh button functional

**Expected Result:** ✅ Trial Balance table should show data

**Try These Tables:**
- ✅ **trial_balance** - Should load data from Reporting Service
- ⚠️ **chart_of_accounts** - Will show "API needs implementation"
- ⚠️ **event_store** - Will show "API needs implementation"
- ⚠️ All others - Show "Direct Database Access Required" (expected)

---

### 8. 🧭 NAVIGATION TESTING

**Mode Switcher:**
- [ ] Click "📊 Reports" button (should be active/highlighted)
- [ ] Click "🤖 AI Assistant" button
- [ ] Should switch to Chat mode
- [ ] Sidebar content should change
- [ ] Switch back to Reports mode

**Sidebar Navigation:**
- [ ] Click through each section (1-6)
- [ ] Each page should load in iframe
- [ ] No console errors
- [ ] Back button works in browser

**Command Palette:**
- [ ] Press "/" key
- [ ] Command palette opens
- [ ] Type "trial" in search
- [ ] "Trial Balance" appears in results
- [ ] Click to navigate
- [ ] Press "Esc" to close
- [ ] Try "Ctrl+K" or "Cmd+K"

**Floating AI Assistant:**
- [ ] Bottom-right bubble visible (🤖)
- [ ] Click bubble
- [ ] Side panel slides in from right
- [ ] Input box present
- [ ] Close button works (×)
- [ ] Click bubble again to toggle

---

## Known Issues & Workarounds

### ❌ Issue 1: JE Register Not Loading
**Symptom:** Loading spinner, then error message
**Cause:** Event Store GET API not implemented
**Impact:** Cannot view posted journal entries in register
**Workaround:** View Trial Balance instead to see transaction impact

### ❌ Issue 2: GL Line Items Not Loading
**Symptom:** Loading spinner, then error message
**Cause:** Same as Issue 1
**Impact:** Cannot see transaction details
**Workaround:** Post entries work, just can't view them yet

### ❌ Issue 3: Chart of Accounts Empty
**Symptom:** "No accounts found" message
**Cause:** COA GET API not implemented
**Impact:** Cannot view/search chart of accounts in Master Data
**Workaround:** Accounts still exist in database, posting works

---

## What's Working ✅

1. **Navigation** - All navigation elements functional
2. **Journal Entry Posting** - Can post entries successfully
3. **Trial Balance** - Full report with all accounts and balances
4. **Database Explorer** - Can view Trial Balance data
5. **UI/UX** - Modern dark theme, smooth transitions
6. **Command Palette** - Quick navigation works
7. **Mode Switching** - Reports ↔ AI Assistant toggle
8. **Keyboard Shortcuts** - All shortcuts functional

---

## What Needs APIs 🔧

1. **Event Store GET** - For JE Register and GL Line Items
2. **Chart of Accounts GET** - For Master Data COA tab
3. **Tenants API** - Currently using fallback data

---

## Quick Test Scenario

**Scenario:** Post a new journal entry and verify it appears in Trial Balance

**Steps:**
1. Navigate to "3. Postings" → "Journal Entry"
2. Set entry date to today
3. Add two lines:
   - Line 1: Account 1200 (AR), DR: 10,000, Description: "Test customer invoice"
   - Line 2: Account 4000 (Revenue), CR: 10,000, Description: "Test revenue"
4. Click "Post Entry"
5. Wait for success message
6. Navigate to "5. Financial Reports" → "Trial Balance"
7. Click Refresh button
8. Verify account 1200 shows 10,000 AED debit increase
9. Verify account 4000 shows 10,000 AED credit increase
10. Verify Trial Balance still shows "✓ Balanced"

**Expected Result:** ✅ Trial Balance updates with new amounts, remains balanced

---

## Final Notes

✅ **Test data preserved** - All 5 journal entries remain in database
✅ **17 pages created** - 8 functional, 9 placeholders
✅ **Modern UI** - Clean, professional accounting system interface
✅ **Proper structure** - Follows ERP best practices

**Next Development Steps:**
1. Implement Event Store GET API
2. Implement Chart of Accounts GET API
3. Complete AP/AR invoice posting pages
4. Add Income Statement and Balance Sheet reports

---

**Happy Testing!** 🎉

For detailed test results, see `TEST_REPORT.md`
