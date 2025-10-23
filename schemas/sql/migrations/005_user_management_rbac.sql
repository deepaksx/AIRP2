-- ============================================
-- AIRP v2.13.0 - User Management & RBAC
-- Role-Based Access Control with Activity Tracking
-- ============================================

-- ============================================
-- USERS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL, -- bcrypt hash
    employee_id VARCHAR(50),
    department VARCHAR(100),
    job_title VARCHAR(100),
    phone VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active', -- active, inactive, suspended, locked
    is_system_user BOOLEAN DEFAULT false, -- For AI agents, batch jobs
    last_login_at TIMESTAMPTZ,
    last_login_ip VARCHAR(45),
    password_changed_at TIMESTAMPTZ,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMPTZ,
    preferences JSONB DEFAULT '{}', -- UI preferences, timezone, language
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(user_id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(user_id),

    -- AI Context Fields (auto-updated)
    ai_context_summary TEXT,
    ai_context_keywords TEXT[],
    ai_context_entities JSONB,
    ai_context_relationships JSONB,
    ai_context_generated_at TIMESTAMPTZ,
    ai_context_model_version VARCHAR(50),

    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_dept ON users(department);
CREATE INDEX idx_users_keywords ON users USING GIN(ai_context_keywords);
CREATE INDEX idx_users_entities ON users USING GIN(ai_context_entities);

-- ============================================
-- ROLES TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS roles (
    role_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    role_code VARCHAR(50) NOT NULL,
    role_name VARCHAR(100) NOT NULL,
    description TEXT,
    is_system_role BOOLEAN DEFAULT false, -- Built-in roles cannot be deleted
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(user_id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(user_id),
    metadata JSONB DEFAULT '{}',
    UNIQUE(tenant_id, role_code)
);

CREATE INDEX idx_roles_tenant ON roles(tenant_id);
CREATE INDEX idx_roles_code ON roles(role_code);
CREATE INDEX idx_roles_active ON roles(is_active);

-- ============================================
-- PERMISSIONS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS permissions (
    permission_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    permission_code VARCHAR(100) UNIQUE NOT NULL,
    permission_name VARCHAR(100) NOT NULL,
    resource VARCHAR(50) NOT NULL, -- journal_entries, vendors, customers, reports, etc.
    action VARCHAR(50) NOT NULL, -- create, read, update, delete, approve, post, etc.
    description TEXT,
    is_system_permission BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_permissions_resource ON permissions(resource);
CREATE INDEX idx_permissions_action ON permissions(action);
CREATE INDEX idx_permissions_code ON permissions(permission_code);

-- ============================================
-- USER ROLES (Many-to-Many)
-- ============================================

CREATE TABLE IF NOT EXISTS user_roles (
    user_role_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    assigned_by UUID REFERENCES users(user_id),
    expires_at TIMESTAMPTZ, -- Optional expiration
    is_active BOOLEAN DEFAULT true,
    UNIQUE(user_id, role_id)
);

CREATE INDEX idx_user_roles_user ON user_roles(user_id);
CREATE INDEX idx_user_roles_role ON user_roles(role_id);
CREATE INDEX idx_user_roles_active ON user_roles(is_active);

-- ============================================
-- ROLE PERMISSIONS (Many-to-Many)
-- ============================================

CREATE TABLE IF NOT EXISTS role_permissions (
    role_permission_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(permission_id) ON DELETE CASCADE,
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    granted_by UUID REFERENCES users(user_id),
    UNIQUE(role_id, permission_id)
);

CREATE INDEX idx_role_permissions_role ON role_permissions(role_id);
CREATE INDEX idx_role_permissions_permission ON role_permissions(permission_id);

-- ============================================
-- USER ACTIVITY LOG
-- Track all user actions for audit and context
-- Partitioned by month
-- ============================================

CREATE TABLE IF NOT EXISTS user_activity_log (
    activity_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    user_id UUID NOT NULL REFERENCES users(user_id),
    activity_type VARCHAR(50) NOT NULL, -- login, logout, create, update, delete, approve, post, view, export
    resource_type VARCHAR(50), -- journal_entry, vendor, customer, report, etc.
    resource_id UUID,
    action_description TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    request_method VARCHAR(10), -- GET, POST, PUT, DELETE
    request_path TEXT,
    response_status INTEGER,
    duration_ms INTEGER, -- Request duration
    activity_data JSONB, -- Additional context
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    session_id UUID
) PARTITION BY RANGE (timestamp);

-- Create partitions for activity log (24 months)
CREATE TABLE user_activity_log_2024_10 PARTITION OF user_activity_log
    FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');
CREATE TABLE user_activity_log_2024_11 PARTITION OF user_activity_log
    FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');
CREATE TABLE user_activity_log_2024_12 PARTITION OF user_activity_log
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');
CREATE TABLE user_activity_log_2025_01 PARTITION OF user_activity_log
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE user_activity_log_2025_02 PARTITION OF user_activity_log
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE user_activity_log_2025_03 PARTITION OF user_activity_log
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE user_activity_log_2025_04 PARTITION OF user_activity_log
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE user_activity_log_2025_05 PARTITION OF user_activity_log
    FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE user_activity_log_2025_06 PARTITION OF user_activity_log
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE user_activity_log_2025_07 PARTITION OF user_activity_log
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE user_activity_log_2025_08 PARTITION OF user_activity_log
    FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE user_activity_log_2025_09 PARTITION OF user_activity_log
    FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE user_activity_log_2025_10 PARTITION OF user_activity_log
    FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE user_activity_log_2025_11 PARTITION OF user_activity_log
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE user_activity_log_2025_12 PARTITION OF user_activity_log
    FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

CREATE INDEX idx_activity_log_user ON user_activity_log(user_id, timestamp DESC);
CREATE INDEX idx_activity_log_tenant ON user_activity_log(tenant_id, timestamp DESC);
CREATE INDEX idx_activity_log_type ON user_activity_log(activity_type);
CREATE INDEX idx_activity_log_resource ON user_activity_log(resource_type, resource_id);
CREATE INDEX idx_activity_log_session ON user_activity_log(session_id);

-- ============================================
-- ADD AI CONTEXT FIELDS TO EXISTING TABLES
-- ============================================

-- Vendors table (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'vendors' AND column_name = 'ai_context_summary'
    ) THEN
        ALTER TABLE vendors ADD COLUMN ai_context_summary TEXT;
        ALTER TABLE vendors ADD COLUMN ai_context_keywords TEXT[];
        ALTER TABLE vendors ADD COLUMN ai_context_entities JSONB;
        ALTER TABLE vendors ADD COLUMN ai_context_relationships JSONB;
        ALTER TABLE vendors ADD COLUMN ai_context_generated_at TIMESTAMPTZ;
        ALTER TABLE vendors ADD COLUMN ai_context_model_version VARCHAR(50);

        CREATE INDEX idx_vendors_keywords ON vendors USING GIN(ai_context_keywords);
        CREATE INDEX idx_vendors_entities ON vendors USING GIN(ai_context_entities);
    END IF;
END $$;

-- Customers table (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'customers' AND column_name = 'ai_context_summary'
    ) THEN
        ALTER TABLE customers ADD COLUMN ai_context_summary TEXT;
        ALTER TABLE customers ADD COLUMN ai_context_keywords TEXT[];
        ALTER TABLE customers ADD COLUMN ai_context_entities JSONB;
        ALTER TABLE customers ADD COLUMN ai_context_relationships JSONB;
        ALTER TABLE customers ADD COLUMN ai_context_generated_at TIMESTAMPTZ;
        ALTER TABLE customers ADD COLUMN ai_context_model_version VARCHAR(50);

        CREATE INDEX idx_customers_keywords ON customers USING GIN(ai_context_keywords);
        CREATE INDEX idx_customers_entities ON customers USING GIN(ai_context_entities);
    END IF;
END $$;

-- Chart of Accounts table (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'chart_of_accounts' AND column_name = 'ai_context_summary'
    ) THEN
        ALTER TABLE chart_of_accounts ADD COLUMN ai_context_summary TEXT;
        ALTER TABLE chart_of_accounts ADD COLUMN ai_context_keywords TEXT[];
        ALTER TABLE chart_of_accounts ADD COLUMN ai_context_entities JSONB;
        ALTER TABLE chart_of_accounts ADD COLUMN ai_context_relationships JSONB;
        ALTER TABLE chart_of_accounts ADD COLUMN ai_context_generated_at TIMESTAMPTZ;
        ALTER TABLE chart_of_accounts ADD COLUMN ai_context_model_version VARCHAR(50);

        CREATE INDEX idx_coa_keywords ON chart_of_accounts USING GIN(ai_context_keywords);
        CREATE INDEX idx_coa_entities ON chart_of_accounts USING GIN(ai_context_entities);
    END IF;
END $$;

-- ============================================
-- INSERT DEFAULT SYSTEM PERMISSIONS
-- ============================================

INSERT INTO permissions (permission_code, permission_name, resource, action, description, is_system_permission) VALUES
-- Journal Entries
('je_create', 'Create Journal Entries', 'journal_entries', 'create', 'Create new journal entries', true),
('je_read', 'View Journal Entries', 'journal_entries', 'read', 'View journal entries and registers', true),
('je_update', 'Edit Journal Entries', 'journal_entries', 'update', 'Modify draft journal entries', true),
('je_delete', 'Delete Journal Entries', 'journal_entries', 'delete', 'Delete draft journal entries', true),
('je_approve', 'Approve Journal Entries', 'journal_entries', 'approve', 'Approve pending journal entries', true),
('je_post', 'Post Journal Entries', 'journal_entries', 'post', 'Post journal entries to GL', true),
('je_reverse', 'Reverse Journal Entries', 'journal_entries', 'reverse', 'Create reversing entries', true),

-- Vendors
('vendor_create', 'Create Vendors', 'vendors', 'create', 'Create new vendor records', true),
('vendor_read', 'View Vendors', 'vendors', 'read', 'View vendor master data', true),
('vendor_update', 'Edit Vendors', 'vendors', 'update', 'Modify vendor information', true),
('vendor_delete', 'Delete Vendors', 'vendors', 'delete', 'Delete vendor records', true),

-- Customers
('customer_create', 'Create Customers', 'customers', 'create', 'Create new customer records', true),
('customer_read', 'View Customers', 'customers', 'read', 'View customer master data', true),
('customer_update', 'Edit Customers', 'customers', 'update', 'Modify customer information', true),
('customer_delete', 'Delete Customers', 'customers', 'delete', 'Delete customer records', true),

-- Chart of Accounts
('coa_create', 'Create Accounts', 'chart_of_accounts', 'create', 'Create new GL accounts', true),
('coa_read', 'View Chart of Accounts', 'chart_of_accounts', 'read', 'View chart of accounts', true),
('coa_update', 'Edit Accounts', 'chart_of_accounts', 'update', 'Modify GL account properties', true),
('coa_delete', 'Delete Accounts', 'chart_of_accounts', 'delete', 'Delete GL accounts', true),

-- Reports
('report_trial_balance', 'Trial Balance Report', 'reports', 'view_trial_balance', 'View trial balance report', true),
('report_income_statement', 'Income Statement Report', 'reports', 'view_income_statement', 'View income statement', true),
('report_balance_sheet', 'Balance Sheet Report', 'reports', 'view_balance_sheet', 'View balance sheet', true),
('report_cash_flow', 'Cash Flow Report', 'reports', 'view_cash_flow', 'View cash flow statement', true),
('report_gl', 'General Ledger Report', 'reports', 'view_gl', 'View GL line items', true),
('report_export', 'Export Reports', 'reports', 'export', 'Export reports to Excel/PDF', true),

-- User Management
('user_create', 'Create Users', 'users', 'create', 'Create new user accounts', true),
('user_read', 'View Users', 'users', 'read', 'View user accounts', true),
('user_update', 'Edit Users', 'users', 'update', 'Modify user information', true),
('user_delete', 'Delete Users', 'users', 'delete', 'Delete user accounts', true),
('user_reset_password', 'Reset Passwords', 'users', 'reset_password', 'Reset user passwords', true),

-- Role Management
('role_create', 'Create Roles', 'roles', 'create', 'Create new roles', true),
('role_read', 'View Roles', 'roles', 'read', 'View roles and permissions', true),
('role_update', 'Edit Roles', 'roles', 'update', 'Modify role permissions', true),
('role_delete', 'Delete Roles', 'roles', 'delete', 'Delete roles', true),

-- System Administration
('system_config', 'System Configuration', 'system', 'configure', 'Modify system settings', true),
('system_audit', 'View Audit Logs', 'system', 'view_audit', 'View user activity logs', true),
('system_backup', 'Backup & Restore', 'system', 'backup', 'Perform system backups', true)
ON CONFLICT (permission_code) DO NOTHING;

-- ============================================
-- INSERT DEFAULT SYSTEM ROLES
-- ============================================

-- Note: We'll insert these via the application to get proper tenant_id
-- These are templates for the application to create per tenant

-- System Administrator (all permissions)
-- Accountant (full accounting operations, no user management)
-- Auditor (read-only access to all financial data)
-- AP Clerk (AP operations only)
-- AR Clerk (AR operations only)
-- Viewer (read-only access to reports)

-- ============================================
-- VIEWS FOR EASY QUERYING
-- ============================================

-- User with roles view
CREATE OR REPLACE VIEW vw_user_roles AS
SELECT
    u.user_id,
    u.tenant_id,
    u.username,
    u.email,
    u.full_name,
    u.department,
    u.job_title,
    u.status,
    json_agg(
        json_build_object(
            'role_id', r.role_id,
            'role_code', r.role_code,
            'role_name', r.role_name,
            'assigned_at', ur.assigned_at,
            'expires_at', ur.expires_at
        )
    ) FILTER (WHERE r.role_id IS NOT NULL) as roles
FROM users u
LEFT JOIN user_roles ur ON u.user_id = ur.user_id AND ur.is_active = true
LEFT JOIN roles r ON ur.role_id = r.role_id AND r.is_active = true
GROUP BY u.user_id, u.username, u.email, u.full_name, u.department, u.job_title, u.status, u.tenant_id;

-- User permissions view (all permissions from all roles)
CREATE OR REPLACE VIEW vw_user_permissions AS
SELECT DISTINCT
    u.user_id,
    u.tenant_id,
    u.username,
    p.permission_id,
    p.permission_code,
    p.permission_name,
    p.resource,
    p.action
FROM users u
JOIN user_roles ur ON u.user_id = ur.user_id AND ur.is_active = true
JOIN roles r ON ur.role_id = r.role_id AND r.is_active = true
JOIN role_permissions rp ON r.role_id = rp.role_id
JOIN permissions p ON rp.permission_id = p.permission_id;

-- User activity summary view
CREATE OR REPLACE VIEW vw_user_activity_summary AS
SELECT
    u.user_id,
    u.username,
    u.full_name,
    u.last_login_at,
    COUNT(DISTINCT al.activity_id) as total_activities,
    COUNT(DISTINCT CASE WHEN al.timestamp >= NOW() - INTERVAL '24 hours' THEN al.activity_id END) as activities_today,
    COUNT(DISTINCT CASE WHEN al.timestamp >= NOW() - INTERVAL '7 days' THEN al.activity_id END) as activities_week,
    COUNT(DISTINCT CASE WHEN al.timestamp >= NOW() - INTERVAL '30 days' THEN al.activity_id END) as activities_month,
    MAX(al.timestamp) as last_activity_at,
    json_agg(
        DISTINCT jsonb_build_object(
            'activity_type', al.activity_type,
            'count', (SELECT COUNT(*) FROM user_activity_log WHERE user_id = u.user_id AND activity_type = al.activity_type)
        )
    ) as activity_breakdown
FROM users u
LEFT JOIN user_activity_log al ON u.user_id = al.user_id
GROUP BY u.user_id, u.username, u.full_name, u.last_login_at;

-- ============================================
-- FUNCTIONS FOR CONTEXT AUTO-UPDATE
-- ============================================

-- Function to track when master data changes (for context updates)
CREATE OR REPLACE FUNCTION trigger_context_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Set a flag in metadata to indicate context needs update
    NEW.metadata = COALESCE(NEW.metadata, '{}'::jsonb) ||
                   jsonb_build_object('context_update_needed', true, 'context_update_triggered_at', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to users table
DROP TRIGGER IF EXISTS users_context_update ON users;
CREATE TRIGGER users_context_update
    BEFORE INSERT OR UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION trigger_context_update();

-- Apply trigger to vendors table (if exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vendors') THEN
        DROP TRIGGER IF EXISTS vendors_context_update ON vendors;
        CREATE TRIGGER vendors_context_update
            BEFORE INSERT OR UPDATE ON vendors
            FOR EACH ROW
            EXECUTE FUNCTION trigger_context_update();
    END IF;
END $$;

-- Apply trigger to customers table (if exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customers') THEN
        DROP TRIGGER IF EXISTS customers_context_update ON customers;
        CREATE TRIGGER customers_context_update
            BEFORE INSERT OR UPDATE ON customers
            FOR EACH ROW
            EXECUTE FUNCTION trigger_context_update();
    END IF;
END $$;

-- Apply trigger to chart_of_accounts table
DROP TRIGGER IF EXISTS coa_context_update ON chart_of_accounts;
CREATE TRIGGER coa_context_update
    BEFORE INSERT OR UPDATE ON chart_of_accounts
    FOR EACH ROW
    EXECUTE FUNCTION trigger_context_update();

-- ============================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON TABLE users IS 'System users with authentication and AI context tracking';
COMMENT ON TABLE roles IS 'User roles for RBAC (Role-Based Access Control)';
COMMENT ON TABLE permissions IS 'Granular permissions for resources and actions';
COMMENT ON TABLE user_roles IS 'Many-to-many relationship between users and roles';
COMMENT ON TABLE role_permissions IS 'Many-to-many relationship between roles and permissions';
COMMENT ON TABLE user_activity_log IS 'Comprehensive audit log of all user activities';

COMMENT ON COLUMN users.ai_context_summary IS 'AI-generated plain English summary of user behavior and patterns';
COMMENT ON COLUMN users.ai_context_keywords IS 'Searchable keywords extracted from user activities';
COMMENT ON COLUMN users.ai_context_entities IS 'Structured entities (departments, frequent actions, etc.)';
COMMENT ON COLUMN users.ai_context_relationships IS 'Related records (most accessed customers, vendors, accounts)';
