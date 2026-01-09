-- Initialize databases and users for RMS Platform
-- This script runs automatically on first PostgreSQL initialization
-- 
-- Architecture:
-- - postgres (superuser) - used to create tenant databases dynamically
-- - rms_gateway database - gateway's master database for tenants, platforms, etc.
-- - Platform databases (rms_template, rms_default, etc.) - created by PlatformDatabaseInitializer
-- - Tenant databases ({platform}_{tenant_key}) - created dynamically when tenants are created

-- Note: CREATE DATABASE cannot run inside a transaction, so databases are created
-- by separate shell scripts

-- Create user/role for Gateway (for its master database operations)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rms_gateway') THEN
    CREATE ROLE rms_gateway WITH LOGIN PASSWORD 'rms_gateway';
    RAISE NOTICE 'Created role: rms_gateway';
  ELSE
    RAISE NOTICE 'Role rms_gateway already exists';
  END IF;
END
$$;

-- Note: Platform databases and tenant databases are created dynamically by:
-- 1. PlatformDatabaseInitializer (creates template and default databases for each platform on startup)
-- 2. DatabaseProvisioningService (creates tenant databases when a new tenant selects "Use Platform Database")

-- Grant privileges will be applied by the database-specific init scripts

DO $$
BEGIN
  RAISE NOTICE '===========================================';
  RAISE NOTICE 'PostgreSQL initialization completed!';
  RAISE NOTICE '';
  RAISE NOTICE 'Users created:';
  RAISE NOTICE '  - postgres (superuser) - for platform DB management';
  RAISE NOTICE '  - rms_gateway - for gateway master database';
  RAISE NOTICE '';
  RAISE NOTICE 'Platform DBs will be created by app on startup:';
  RAISE NOTICE '  - rms_template, rms_default';
  RAISE NOTICE '  - ecm_template, ecm_default';
  RAISE NOTICE '  - nbk_template, nbk_default';
  RAISE NOTICE '  - awd_template, awd_default';
  RAISE NOTICE '  - vpm_template, vpm_default';
  RAISE NOTICE '  - hms_template, hms_default';
  RAISE NOTICE '  - ems_template, ems_default';
  RAISE NOTICE '  - dms_template, dms_default';
  RAISE NOTICE '===========================================';
END
$$;

