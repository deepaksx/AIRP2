# User Management & RBAC System - AIRP v2.13.0

## Overview

Complete user management system with Role-Based Access Control (RBAC), user activity tracking, behavior analysis, and automatic AI context generation for all master data entities.

## Key Features

### 1. User Management
- **Full CRUD Operations**: Create, read, update, and delete user accounts
- **Authentication**: Secure password hashing with bcrypt
- **Account Security**:
  - Failed login attempt tracking
  - Automatic account locking after 5 failed attempts
  - 30-minute lockout period
  - Password change tracking
- **User Profiles**:
  - Username, email, full name
  - Employee ID, department, job title
  - Phone number
  - Custom preferences (UI settings, timezone, language)
- **Status Management**: Active, Inactive, Suspended, Locked
- **System Users**: Support for AI agents and batch jobs

### 2. Role-Based Access Control (RBAC)

**Roles**:
- System-defined roles (cannot be deleted)
- Custom tenant-specific roles
- Hierarchical role structure
- Active/inactive toggle

**Permissions**:
- 40+ granular permissions across all resources
- Resource-action pairs (e.g., journal_entries:create)
- Categories:
  - Journal Entries (7 permissions)
  - Vendors (4 permissions)
  - Customers (4 permissions)
  - Chart of Accounts (4 permissions)
  - Reports (6 permissions)
  - User Management (5 permissions)
  - Role Management (4 permissions)
  - System Administration (3 permissions)

**Permission Assignment**:
- Many-to-many relationship between roles and permissions
- Many-to-many relationship between users and roles
- Optional role expiration dates
- Audit trail of permission grants

### 3. User Activity Tracking

**Comprehensive Logging**:
- Every user action logged with full context
- Activity types: login, logout, create, update, delete, approve, post, view, export
- Captured data:
  - Timestamp (partitioned by month for performance)
  - IP address and user agent
  - Resource type and ID
  - Action description
  - Request method and path
  - Response status code
  - Request duration (ms)
  - Session ID
  - Custom activity data (JSONB)

**Performance**:
- Partitioned by month for fast queries
- Indexes on user_id, tenant_id, timestamp
- Automatic partition creation for 15 months

**Analytics**:
- User activity summary view
- Activity breakdown by type
- Resource access patterns
- Recent activity queries

### 4. AI Context Generation

**Automatic Context for All Entities**:
- **Users**: Behavior patterns, frequently accessed resources, work patterns
- **Vendors**: Transaction history, payment patterns, most used accounts
- **Customers**: Purchase behavior, payment history, relationship strength
- **Chart of Accounts**: Usage patterns, common entry types, related accounts

**Context Fields** (all master data tables):
- `ai_context_summary`: Plain English description
- `ai_context_keywords`: Searchable keyword array (GIN indexed)
- `ai_context_entities`: Structured entities (JSONB)
- `ai_context_relationships`: Related records (JSONB)
- `ai_context_generated_at`: Generation timestamp
- `ai_context_model_version`: AI model version (e.g., claude-3.5-sonnet)

**Auto-Update Worker**:
- Runs every 5 minutes via cron job
- Updates 10 entities per run per type
- Triggers on:
  - Manual flag in metadata (`context_update_needed`)
  - Null context (new entities)
  - Stale context (30+ days old for users/vendors/customers, 90+ days for GL accounts)
- Non-blocking: failures don't affect main operations
- Parallel processing for different entity types

**Context Generation Process**:
1. Worker identifies entities needing updates
2. Fetches entity data + related transaction stats
3. Calls AI Context Generator service (port 8007)
4. Stores generated context in database
5. Clears update flag

### 5. Event-Driven Architecture

**Database Triggers**:
- Automatic flag setting when master data changes
- Before insert/update triggers on:
  - users
  - vendors
  - customers
  - chart_of_accounts
- Trigger function: `trigger_context_update()`

**Transaction Events**:
- Journal entry posting triggers context updates for:
  - Affected GL accounts
  - Related vendors (dimension_1)
  - Related customers (dimension_2)
  - User who posted the entry

## Database Schema

### Core Tables

**users**:
```sql
- user_id (UUID, PK)
- tenant_id (UUID, FK)
- username (VARCHAR(100), UNIQUE)
- email (VARCHAR(255), UNIQUE)
- password_hash (VARCHAR(255))
- full_name, employee_id, department, job_title, phone
- status (active/inactive/suspended/locked)
- is_system_user (BOOLEAN)
- last_login_at, last_login_ip
- password_changed_at
- failed_login_attempts, locked_until
- preferences (JSONB)
- ai_context_* fields (6 columns)
- created_at, created_by, updated_at, updated_by
- metadata (JSONB)
```

**roles**:
```sql
- role_id (UUID, PK)
- tenant_id (UUID, FK)
- role_code (VARCHAR(50))
- role_name (VARCHAR(100))
- description (TEXT)
- is_system_role, is_active
- created_at, created_by, updated_at, updated_by
- metadata (JSONB)
```

**permissions**:
```sql
- permission_id (UUID, PK)
- permission_code (VARCHAR(100), UNIQUE)
- permission_name (VARCHAR(100))
- resource (VARCHAR(50)) - journal_entries, vendors, etc.
- action (VARCHAR(50)) - create, read, update, delete, etc.
- description (TEXT)
- is_system_permission (BOOLEAN)
- created_at, metadata (JSONB)
```

**user_roles**:
```sql
- user_role_id (UUID, PK)
- user_id (UUID, FK users)
- role_id (UUID, FK roles)
- assigned_at, assigned_by
- expires_at (optional)
- is_active
```

**role_permissions**:
```sql
- role_permission_id (UUID, PK)
- role_id (UUID, FK roles)
- permission_id (UUID, FK permissions)
- granted_at, granted_by
```

**user_activity_log** (partitioned):
```sql
- activity_id (UUID, PK)
- tenant_id, user_id
- activity_type (VARCHAR(50))
- resource_type, resource_id
- action_description (TEXT)
- ip_address, user_agent
- request_method, request_path
- response_status, duration_ms
- activity_data (JSONB)
- timestamp (partitioned by month)
- session_id
```

### Views

**vw_user_roles**:
- Aggregates users with their assigned roles
- JSON array of role details per user

**vw_user_permissions**:
- All permissions for a user (from all roles)
- Flattened for easy permission checks

**vw_user_activity_summary**:
- User activity statistics
- Today/week/month activity counts
- Activity type breakdown
- Last activity timestamp

## API Endpoints

### User Management Service (Port 3009)

**Users**:
- `GET /users?tenant_id={id}` - List all users
- `GET /users/search?tenant_id={id}&q={query}` - Search users
- `GET /users/:id` - Get user details
- `GET /users/:id/permissions` - Get user permissions
- `GET /users/:id/activity?limit={n}` - Get user activity log
- `POST /users` - Create user
- `PUT /users/:id` - Update user
- `DELETE /users/:id?deleted_by={id}` - Delete user (soft delete)
- `POST /users/:id/regenerate-context` - Manually regenerate AI context

**Health**:
- `GET /health` - Service health check

## User Interface

### User Management Page (`user-management.html`)

**Features**:
- Grid view of all users with avatars
- Real-time search across username, email, department, AI keywords
- User cards showing:
  - Avatar with initials
  - Full name, username, email
  - Department and job title
  - AI context summary
  - Status badge
  - Action buttons
- Create user modal form
- Edit user inline
- View user details
- Regenerate AI context button
- Responsive design with SAP styling

**Navigation**:
- Accessible from main dashboard sidebar
- Section 5: System & Administration
- Highlighted as important feature

## Default Permissions

### Journal Entries
- `je_create` - Create new journal entries
- `je_read` - View journal entries and registers
- `je_update` - Modify draft journal entries
- `je_delete` - Delete draft journal entries
- `je_approve` - Approve pending journal entries
- `je_post` - Post journal entries to GL
- `je_reverse` - Create reversing entries

### Master Data
- `vendor_create/read/update/delete`
- `customer_create/read/update/delete`
- `coa_create/read/update/delete` (Chart of Accounts)

### Reports
- `report_trial_balance`
- `report_income_statement`
- `report_balance_sheet`
- `report_cash_flow`
- `report_gl`
- `report_export`

### Administration
- `user_create/read/update/delete/reset_password`
- `role_create/read/update/delete`
- `system_config/audit/backup`

## Suggested Role Templates

### System Administrator
- All permissions
- Full system access
- User and role management

### Accountant
- All journal entry permissions
- All master data permissions
- All report permissions
- No user/role management

### Auditor
- Read-only access to all data
- All report permissions
- View audit logs
- No create/update/delete

### AP Clerk
- Vendor management
- AP invoice creation
- AP-related journal entries
- AP reports

### AR Clerk
- Customer management
- AR invoice creation
- AR-related journal entries
- AR reports

### Viewer
- Read-only access
- View reports only
- No data modification

## Implementation Guide

### 1. Database Setup

```bash
# Run migration
psql -U airp_admin -d airp_master -f schemas/sql/migrations/005_user_management_rbac.sql
```

### 2. Start User Management Service

```bash
cd services/user-management-service
npm install
npm run start:dev  # Development
# or
npm run build && npm run start:prod  # Production
```

Service runs on port 3009 by default.

### 3. Create First Admin User

```bash
curl -X POST http://localhost:3009/users \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "00000000-0000-0000-0000-000000000001",
    "username": "admin",
    "email": "admin@example.com",
    "full_name": "System Administrator",
    "password": "secure_password_here",
    "department": "IT",
    "job_title": "System Administrator",
    "status": "active"
  }'
```

### 4. Create Roles and Assign Permissions

```sql
-- Create System Administrator role
INSERT INTO roles (tenant_id, role_code, role_name, description, is_system_role)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'SYS_ADMIN',
  'System Administrator',
  'Full system access with all permissions',
  true
);

-- Grant all permissions to System Administrator role
INSERT INTO role_permissions (role_id, permission_id)
SELECT
  (SELECT role_id FROM roles WHERE role_code = 'SYS_ADMIN'),
  permission_id
FROM permissions;

-- Assign role to user
INSERT INTO user_roles (user_id, role_id, assigned_by)
VALUES (
  '{user_id_from_step_3}',
  (SELECT role_id FROM roles WHERE role_code = 'SYS_ADMIN'),
  '{user_id_from_step_3}'
);
```

## Context Update Worker

### Configuration

Environment variables:
```bash
AI_CONTEXT_SERVICE_URL=http://localhost:8007  # AI Context Generator service
```

### Monitoring

Check worker status:
```sql
-- Entities pending context update
SELECT
  'users' as entity_type,
  COUNT(*) as pending_count
FROM users
WHERE (metadata->>'context_update_needed')::boolean = true
   OR ai_context_generated_at IS NULL
   OR ai_context_generated_at < NOW() - INTERVAL '30 days'

UNION ALL

SELECT 'vendors', COUNT(*) FROM vendors
WHERE (metadata->>'context_update_needed')::boolean = true
   OR ai_context_generated_at IS NULL

UNION ALL

SELECT 'customers', COUNT(*) FROM customers
WHERE (metadata->>'context_update_needed')::boolean = true
   OR ai_context_generated_at IS NULL

UNION ALL

SELECT 'chart_of_accounts', COUNT(*) FROM chart_of_accounts
WHERE (metadata->>'context_update_needed')::boolean = true
   OR ai_context_generated_at IS NULL;
```

### Manual Trigger

```bash
# Regenerate context for specific user
curl -X POST http://localhost:3009/users/{user_id}/regenerate-context

# Or mark for update in next cycle
UPDATE users
SET metadata = metadata || '{"context_update_needed": true}'
WHERE user_id = '{user_id}';
```

## Security Considerations

1. **Password Storage**:
   - Bcrypt hashing with salt rounds = 10
   - Never store plain text passwords
   - Password change tracking

2. **Account Locking**:
   - Automatic lockout after 5 failed attempts
   - 30-minute cooldown period
   - Manual unlock by admin

3. **Permission Checks**:
   - Always verify user permissions before operations
   - Use `vw_user_permissions` view for fast lookups
   - Deny by default (whitelist approach)

4. **Activity Logging**:
   - All user actions logged
   - IP address tracking
   - Session management
   - Audit trail for compliance

5. **AI Context**:
   - Non-critical: failures don't block operations
   - Async generation
   - Privacy considerations for summary content

## Performance Optimizations

1. **Partitioning**:
   - Activity log partitioned by month
   - Automatic partition management

2. **Indexes**:
   - GIN indexes on keyword arrays
   - B-tree indexes on foreign keys
   - Composite indexes on common queries

3. **Caching**:
   - User permissions can be cached
   - TTL: 5 minutes recommended
   - Invalidate on role changes

4. **Parallel Processing**:
   - Context updates run in parallel per entity type
   - Batch size: 10 entities per run
   - Non-blocking async operations

## Troubleshooting

**Service won't start**:
- Check database connection
- Verify migrations run successfully
- Check port 3009 is available

**Context updates not working**:
- Verify AI Context Generator service running on port 8007
- Check worker logs for errors
- Verify database triggers installed

**Permission checks failing**:
- Verify role assignments active
- Check role_permissions table populated
- Use vw_user_permissions view

**Activity log too large**:
- Old partitions can be dropped
- Recommended retention: 12-24 months
- Archive to cold storage if needed

## Future Enhancements

1. **OAuth2/OIDC Integration**: External identity providers
2. **Multi-Factor Authentication**: TOTP, SMS, email
3. **API Rate Limiting**: Per-user request throttling
4. **Advanced Analytics**: User behavior patterns, anomaly detection
5. **Context Recommendations**: AI-suggested actions based on patterns
6. **Delegation**: Temporary permission delegation
7. **Approval Workflows**: Multi-level approval chains

## Version History

- **v2.13.0** (October 2025): Initial release
  - User management with RBAC
  - 40+ granular permissions
  - Activity tracking with partitioning
  - Auto-updating AI context for all entities
  - Context update worker with cron scheduling
  - User management UI

---

**Files**:
- Database: `schemas/sql/migrations/005_user_management_rbac.sql`
- Service: `services/user-management-service/`
- UI: `user-management.html`
- Documentation: `docs/USER_MANAGEMENT_RBAC.md`
