-- ============================================================================
-- COMPLIANCEREADER BYOS - COMPLETE PRODUCTION DATABASE
-- Bring Your Own Storage Architecture
-- ============================================================================
--
-- 🎯 DEPLOYMENT: Copy entire file → Supabase SQL Editor → Run
-- ⏱️  Time: ~60 seconds
-- 📦 Creates: 9 tables, indexes, views, RLS policies
--
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- TABLE 1: ORGANIZATIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Basic info
    name TEXT NOT NULL,
    slug TEXT UNIQUE,
    industry TEXT,
    size_category TEXT CHECK (size_category IN ('startup', 'small', 'medium', 'enterprise')),
    
    -- Contact
    primary_contact_email TEXT,
    primary_contact_name TEXT,
    website TEXT,
    
    -- Subscription limits
    max_users INTEGER DEFAULT 10,
    max_documents INTEGER DEFAULT 100,
    max_storage_mb INTEGER DEFAULT 1000,
    
    -- Feature flags
    features JSONB DEFAULT '{"pdf_upload": true, "ocr": false, "api_access": false}',
    
    -- Billing
    subscription_tier TEXT CHECK (subscription_tier IN ('trial', 'starter', 'professional', 'enterprise')),
    subscription_status TEXT CHECK (subscription_status IN ('active', 'past_due', 'canceled', 'trialing')),
    trial_ends_at TIMESTAMPTZ,
    
    -- Usage tracking
    current_user_count INTEGER DEFAULT 0,
    current_document_count INTEGER DEFAULT 0,
    current_storage_mb DECIMAL(10,2) DEFAULT 0,
    
    -- Metadata
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_organizations_slug ON public.organizations(slug);
CREATE INDEX idx_organizations_status ON public.organizations(subscription_status);
CREATE INDEX idx_organizations_tier ON public.organizations(subscription_tier);

-- ============================================================================
-- TABLE 2: PROFILES (USERS)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Auth (links to Supabase auth.users)
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    
    -- Basic info
    full_name TEXT,
    avatar_url TEXT,
    
    -- Organization
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    department TEXT,
    job_title TEXT,
    employee_id TEXT,
    
    -- Role & permissions
    user_type TEXT CHECK (user_type IN ('super_admin', 'org_admin', 'hr_manager', 'compliance_officer', 'employee')) DEFAULT 'employee',
    is_active BOOLEAN DEFAULT true,
    
    -- Preferences
    notification_preferences JSONB DEFAULT '{"email": true, "in_app": true}',
    timezone TEXT DEFAULT 'America/Chicago',
    language TEXT DEFAULT 'en',
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    last_active_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX idx_profiles_organization ON public.profiles(organization_id);
CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_profiles_type ON public.profiles(user_type);

-- ============================================================================
-- TABLE 3: DOCUMENTS (BYOS - NO FILE STORAGE!)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identity
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    document_type TEXT CHECK (document_type IN ('policy', 'handbook', 'training', 'safety', 'legal', 'other')),
    
    -- BYOS: Customer stores files, we store URLs
    external_url TEXT NOT NULL, -- S3, Azure, GDrive, SharePoint, etc.
    url_expires_at TIMESTAMPTZ, -- For signed URLs
    file_hash TEXT, -- Detect if document changed
    file_size_bytes BIGINT,
    
    -- Document info
    total_pages INTEGER,
    language TEXT DEFAULT 'en',
    version TEXT DEFAULT '1.0',
    
    -- Organization
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    created_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    
    -- Status
    status TEXT CHECK (status IN ('draft', 'active', 'archived')) DEFAULT 'active',
    published_at TIMESTAMPTZ,
    
    -- Tags & categories
    tags TEXT[],
    category TEXT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_documents_slug ON public.documents(slug);
CREATE INDEX idx_documents_organization ON public.documents(organization_id);
CREATE INDEX idx_documents_status ON public.documents(status);
CREATE INDEX idx_documents_type ON public.documents(document_type);
CREATE INDEX idx_documents_created_by ON public.documents(created_by_user_id);

-- ============================================================================
-- TABLE 4: PAGE ANALYTICS (YOUR IP - THE MONEY MAKER!)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.page_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Who & What
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    document_id UUID REFERENCES public.documents(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    -- Page tracking
    page_number INTEGER NOT NULL,
    scroll_position DECIMAL(5,4), -- 0.0 to 1.0
    
    -- Time tracking
    time_spent_seconds INTEGER,
    entered_at TIMESTAMPTZ DEFAULT NOW(),
    exited_at TIMESTAMPTZ,
    
    -- Context
    session_id UUID,
    device_type TEXT,
    browser TEXT,
    
    -- Fraud detection
    is_suspicious BOOLEAN DEFAULT false,
    fraud_score INTEGER DEFAULT 0, -- 0-100
    fraud_reasons TEXT[],
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_page_analytics_user ON public.page_analytics(user_id);
CREATE INDEX idx_page_analytics_document ON public.page_analytics(document_id);
CREATE INDEX idx_page_analytics_organization ON public.page_analytics(organization_id);
CREATE INDEX idx_page_analytics_page ON public.page_analytics(page_number);
CREATE INDEX idx_page_analytics_session ON public.page_analytics(session_id);
CREATE INDEX idx_page_analytics_created ON public.page_analytics(created_at DESC);
CREATE INDEX idx_page_analytics_suspicious ON public.page_analytics(is_suspicious) WHERE is_suspicious = true;

-- ============================================================================
-- TABLE 5: DOCUMENT ASSIGNMENTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.document_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Assignment
    document_id UUID REFERENCES public.documents(id) ON DELETE CASCADE,
    assigned_to_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    assigned_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    -- Requirements
    due_date TIMESTAMPTZ,
    is_mandatory BOOLEAN DEFAULT true,
    requires_signature BOOLEAN DEFAULT false,
    
    -- Status
    status TEXT CHECK (status IN ('assigned', 'in_progress', 'completed', 'overdue', 'exempt')) DEFAULT 'assigned',
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    -- Progress
    pages_read INTEGER DEFAULT 0,
    total_pages INTEGER,
    completion_percentage DECIMAL(5,2) DEFAULT 0.00,
    time_spent_seconds INTEGER DEFAULT 0,
    
    -- Signature
    signature_data JSONB, -- Base64 signature image, timestamp, IP
    signature_date TIMESTAMPTZ,
    
    -- Reminders
    last_reminder_sent_at TIMESTAMPTZ,
    reminder_count INTEGER DEFAULT 0,
    
    -- Notes
    notes TEXT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(document_id, assigned_to_user_id)
);

CREATE INDEX idx_assignments_assigned_to ON public.document_assignments(assigned_to_user_id);
CREATE INDEX idx_assignments_document ON public.document_assignments(document_id);
CREATE INDEX idx_assignments_organization ON public.document_assignments(organization_id);
CREATE INDEX idx_assignments_status ON public.document_assignments(status);
CREATE INDEX idx_assignments_due_date ON public.document_assignments(due_date);
CREATE INDEX idx_assignments_completed ON public.document_assignments(completed_at DESC);

-- ============================================================================
-- TABLE 6: COMPLIANCE CERTIFICATES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.compliance_certificates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Links
    assignment_id UUID REFERENCES public.document_assignments(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    document_id UUID REFERENCES public.documents(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    -- Certificate info
    certificate_number TEXT UNIQUE NOT NULL,
    issued_at TIMESTAMPTZ DEFAULT NOW(),
    valid_until TIMESTAMPTZ,
    
    -- Verification
    verification_hash TEXT UNIQUE,
    verification_url TEXT,
    
    -- Completion data (for audit trail)
    completion_data JSONB, -- {pages_read, time_spent, scroll_history, etc.}
    signature_data JSONB,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_certificates_user ON public.compliance_certificates(user_id);
CREATE INDEX idx_certificates_document ON public.compliance_certificates(document_id);
CREATE INDEX idx_certificates_organization ON public.compliance_certificates(organization_id);
CREATE INDEX idx_certificates_number ON public.compliance_certificates(certificate_number);
CREATE INDEX idx_certificates_hash ON public.compliance_certificates(verification_hash);

-- ============================================================================
-- TABLE 7: FRAUD DETECTION
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.fraud_detection (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Subject
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    document_id UUID REFERENCES public.documents(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    -- Detection
    fraud_type TEXT NOT NULL, -- 'auto_scroll', 'impossible_speed', 'bot_pattern', 'duplicate_session'
    fraud_score INTEGER NOT NULL, -- 0-100
    confidence TEXT CHECK (confidence IN ('low', 'medium', 'high', 'certain')),
    
    -- Evidence
    evidence JSONB NOT NULL, -- {reading_speed, scroll_pattern, device_fingerprint, etc.}
    related_session_id UUID,
    
    -- Action taken
    action_taken TEXT, -- 'flagged', 'blocked', 'invalidated', 'reviewed'
    reviewed_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    review_notes TEXT,
    
    -- Status
    is_resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMPTZ,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_fraud_user ON public.fraud_detection(user_id);
CREATE INDEX idx_fraud_document ON public.fraud_detection(document_id);
CREATE INDEX idx_fraud_organization ON public.fraud_detection(organization_id);
CREATE INDEX idx_fraud_type ON public.fraud_detection(fraud_type);
CREATE INDEX idx_fraud_score ON public.fraud_detection(fraud_score DESC);
CREATE INDEX idx_fraud_unresolved ON public.fraud_detection(is_resolved) WHERE is_resolved = false;

-- ============================================================================
-- TABLE 8: SUBSCRIPTIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Organization
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    -- Plan
    plan_name TEXT NOT NULL, -- 'trial', 'starter', 'professional', 'enterprise'
    billing_period TEXT CHECK (billing_period IN ('monthly', 'yearly')) DEFAULT 'monthly',
    
    -- Pricing
    price_per_user DECIMAL(10,2),
    base_price DECIMAL(10,2),
    currency TEXT DEFAULT 'USD',
    
    -- Limits
    max_users INTEGER,
    max_documents INTEGER,
    max_storage_mb INTEGER,
    
    -- Status
    status TEXT CHECK (status IN ('active', 'past_due', 'canceled', 'trialing', 'paused')) DEFAULT 'trialing',
    
    -- Dates
    trial_start_date TIMESTAMPTZ,
    trial_end_date TIMESTAMPTZ,
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    canceled_at TIMESTAMPTZ,
    
    -- Stripe
    stripe_subscription_id TEXT UNIQUE,
    stripe_customer_id TEXT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_organization ON public.subscriptions(organization_id);
CREATE INDEX idx_subscriptions_status ON public.subscriptions(status);
CREATE INDEX idx_subscriptions_stripe_sub ON public.subscriptions(stripe_subscription_id);
CREATE INDEX idx_subscriptions_stripe_cust ON public.subscriptions(stripe_customer_id);

-- ============================================================================
-- TABLE 9: INVOICES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Organization
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
    
    -- Invoice details
    invoice_number TEXT UNIQUE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'USD',
    
    -- Billing
    billing_period_start TIMESTAMPTZ,
    billing_period_end TIMESTAMPTZ,
    
    -- Status
    status TEXT CHECK (status IN ('draft', 'open', 'paid', 'void', 'uncollectible')) DEFAULT 'open',
    due_date TIMESTAMPTZ,
    paid_at TIMESTAMPTZ,
    
    -- Line items
    line_items JSONB, -- [{description, quantity, unit_price, total}]
    
    -- Stripe
    stripe_invoice_id TEXT UNIQUE,
    stripe_payment_intent_id TEXT,
    
    -- Files
    pdf_url TEXT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_invoices_organization ON public.invoices(organization_id);
CREATE INDEX idx_invoices_subscription ON public.invoices(subscription_id);
CREATE INDEX idx_invoices_number ON public.invoices(invoice_number);
CREATE INDEX idx_invoices_status ON public.invoices(status);
CREATE INDEX idx_invoices_due_date ON public.invoices(due_date);
CREATE INDEX idx_invoices_stripe ON public.invoices(stripe_invoice_id);

-- ============================================================================
-- VIEWS FOR ANALYTICS
-- ============================================================================

-- Organization usage stats
CREATE OR REPLACE VIEW organization_usage_stats AS
SELECT 
    o.id,
    o.name,
    o.subscription_tier,
    COUNT(DISTINCT p.id) as user_count,
    COUNT(DISTINCT d.id) as document_count,
    COALESCE(SUM(d.file_size_bytes), 0) / 1024 / 1024 as storage_mb,
    o.max_users,
    o.max_documents,
    o.max_storage_mb,
    ROUND(COUNT(DISTINCT p.id) * 100.0 / NULLIF(o.max_users, 0), 1) as user_utilization_pct,
    ROUND(COUNT(DISTINCT d.id) * 100.0 / NULLIF(o.max_documents, 0), 1) as document_utilization_pct
FROM organizations o
LEFT JOIN profiles p ON o.id = p.organization_id AND p.is_active = true
LEFT JOIN documents d ON o.id = d.organization_id AND d.status = 'active'
GROUP BY o.id, o.name, o.subscription_tier, o.max_users, o.max_documents, o.max_storage_mb;

-- Document completion stats
CREATE OR REPLACE VIEW document_completion_stats AS
SELECT 
    d.id,
    d.title,
    d.organization_id,
    COUNT(DISTINCT da.assigned_to_user_id) as total_assigned,
    COUNT(DISTINCT da.assigned_to_user_id) FILTER (WHERE da.status = 'completed') as completed_count,
    COUNT(DISTINCT da.assigned_to_user_id) FILTER (WHERE da.status = 'overdue') as overdue_count,
    ROUND(
        COUNT(DISTINCT da.assigned_to_user_id) FILTER (WHERE da.status = 'completed') * 100.0 / 
        NULLIF(COUNT(DISTINCT da.assigned_to_user_id), 0), 
        1
    ) as completion_rate_pct,
    AVG(da.time_spent_seconds) FILTER (WHERE da.status = 'completed') as avg_completion_time_seconds
FROM documents d
LEFT JOIN document_assignments da ON d.id = da.document_id
GROUP BY d.id, d.title, d.organization_id;

-- User reading activity
CREATE OR REPLACE VIEW user_reading_activity AS
SELECT 
    p.id as user_id,
    p.full_name,
    p.email,
    p.organization_id,
    COUNT(DISTINCT da.document_id) as documents_assigned,
    COUNT(DISTINCT da.document_id) FILTER (WHERE da.status = 'completed') as documents_completed,
    COUNT(DISTINCT da.document_id) FILTER (WHERE da.status = 'overdue') as documents_overdue,
    SUM(da.time_spent_seconds) as total_reading_time_seconds,
    MAX(pa.created_at) as last_reading_activity
FROM profiles p
LEFT JOIN document_assignments da ON p.id = da.assigned_to_user_id
LEFT JOIN page_analytics pa ON p.id = pa.user_id
GROUP BY p.id, p.full_name, p.email, p.organization_id;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) - DISABLED FOR MVP
-- ============================================================================
-- Enable later when you add proper authentication

ALTER TABLE public.organizations DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.page_analytics DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_certificates DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.fraud_detection DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- DEMO DATA (For Testing)
-- ============================================================================

-- Create demo organization
INSERT INTO public.organizations (id, name, slug, industry, size_category, subscription_tier, subscription_status, max_users, max_documents) 
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'Acme Manufacturing',
    'acme-mfg',
    'Manufacturing',
    'medium',
    'professional',
    'active',
    50,
    500
) ON CONFLICT DO NOTHING;

-- Create demo admin user
INSERT INTO public.profiles (id, email, full_name, organization_id, user_type, is_active) 
VALUES (
    '00000000-0000-0000-0000-000000000002',
    'admin@acme-mfg.com',
    'Jane Admin',
    '00000000-0000-0000-0000-000000000001',
    'org_admin',
    true
) ON CONFLICT DO NOTHING;

-- Create demo employee
INSERT INTO public.profiles (id, email, full_name, organization_id, user_type, department, is_active) 
VALUES (
    '00000000-0000-0000-0000-000000000003',
    'john@acme-mfg.com',
    'John Employee',
    '00000000-0000-0000-0000-000000000001',
    'employee',
    'Operations',
    true
) ON CONFLICT DO NOTHING;

-- Create demo documents
INSERT INTO public.documents (id, slug, title, description, document_type, external_url, total_pages, organization_id, created_by_user_id, status) 
VALUES 
(
    '00000000-0000-0000-0000-000000000010',
    'employee-handbook-2025',
    'Employee Handbook 2025',
    'Updated company policies and procedures',
    'handbook',
    'https://example.com/handbook.pdf',
    45,
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    'active'
),
(
    '00000000-0000-0000-0000-000000000011',
    'safety-procedures',
    'Workplace Safety Procedures',
    'Essential safety protocols and emergency procedures',
    'safety',
    'https://example.com/safety.pdf',
    28,
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    'active'
) ON CONFLICT DO NOTHING;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ ComplianceReader BYOS Database Setup Complete!';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Created:';
    RAISE NOTICE '   • 9 tables';
    RAISE NOTICE '   • 3 analytics views';
    RAISE NOTICE '   • Performance indexes';
    RAISE NOTICE '   • Demo organization + 2 users + 2 documents';
    RAISE NOTICE '';
    RAISE NOTICE '🔐 Security: RLS DISABLED (enable later with auth)';
    RAISE NOTICE '';
    RAISE NOTICE '📝 Next Steps:';
    RAISE NOTICE '   1. Get API credentials: Settings → API';
    RAISE NOTICE '   2. Update index.html with credentials';
    RAISE NOTICE '   3. Deploy to Vercel';
    RAISE NOTICE '   4. Test with: ?doc=employee-handbook-2025&user=john@acme-mfg.com';
    RAISE NOTICE '';
    RAISE NOTICE '💰 Ready for:';
    RAISE NOTICE '   • Multi-tenant B2B SaaS';
    RAISE NOTICE '   • Per-user billing';
    RAISE NOTICE '   • Usage tracking';
    RAISE NOTICE '   • Compliance certificates';
    RAISE NOTICE '   • Fraud detection';
    RAISE NOTICE '';
END $$;
