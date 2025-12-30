-- Initialize databases and users for Gateway and Service
-- This script runs automatically on first PostgreSQL initialization

-- Note: CREATE DATABASE cannot run inside a transaction, so databases are created
-- by separate shell scripts (01-init-gateway-db.sh and 02-init-service-db.sh)

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

-- Grant privileges will be applied by the database-specific init scripts

