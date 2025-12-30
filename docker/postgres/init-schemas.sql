-- Initialize schemas and users for Gateway and Service
-- This script runs automatically on first PostgreSQL initialization

-- Create schema for Gateway
CREATE SCHEMA IF NOT EXISTS rms_gateway;

-- Create schema for Service
CREATE SCHEMA IF NOT EXISTS rms_service;

-- Create user/role for Gateway
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rms_gateway') THEN
    CREATE ROLE rms_gateway WITH LOGIN PASSWORD 'rms_gateway';
  END IF;
END
$$;

-- Create user/role for Service
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rms_service') THEN
    CREATE ROLE rms_service WITH LOGIN PASSWORD 'rms_service';
  END IF;
END
$$;

-- Grant privileges to Gateway user
GRANT ALL PRIVILEGES ON SCHEMA rms_gateway TO rms_gateway;
GRANT ALL PRIVILEGES ON DATABASE rms TO rms_gateway;

-- Grant privileges to Service user
GRANT ALL PRIVILEGES ON SCHEMA rms_service TO rms_service;
GRANT ALL PRIVILEGES ON DATABASE rms TO rms_service;

-- Set default privileges for future objects in Gateway schema
ALTER DEFAULT PRIVILEGES IN SCHEMA rms_gateway GRANT ALL ON TABLES TO rms_gateway;
ALTER DEFAULT PRIVILEGES IN SCHEMA rms_gateway GRANT ALL ON SEQUENCES TO rms_gateway;

-- Set default privileges for future objects in Service schema
ALTER DEFAULT PRIVILEGES IN SCHEMA rms_service GRANT ALL ON TABLES TO rms_service;
ALTER DEFAULT PRIVILEGES IN SCHEMA rms_service GRANT ALL ON SEQUENCES TO rms_service;

