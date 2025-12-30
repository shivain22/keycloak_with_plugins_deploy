-- Initialize schema and users for Gateway and Service
-- This script runs automatically on first PostgreSQL initialization

-- Create schema for Gateway (in 'rms' database)
CREATE SCHEMA IF NOT EXISTS rms_gateway;

-- Create database for Service (if it doesn't exist)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'rms_service') THEN
    PERFORM dblink_exec('dbname=' || current_database(), 'CREATE DATABASE rms_service');
  END IF;
EXCEPTION
  WHEN undefined_function THEN
    -- dblink extension not available, use direct SQL
    -- Note: We can't create database from within a transaction, so this will be handled by a separate script
    RAISE NOTICE 'Database rms_service will be created separately if needed';
END
$$;

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

-- Grant privileges to Gateway user (on 'rms' database with 'rms_gateway' schema)
GRANT ALL PRIVILEGES ON SCHEMA rms_gateway TO rms_gateway;
GRANT ALL PRIVILEGES ON DATABASE rms TO rms_gateway;

-- Grant privileges to Service user (on 'rms_service' database - will be applied when database is created)
GRANT ALL PRIVILEGES ON DATABASE rms_service TO rms_service;

-- Set default privileges for future objects in Gateway schema
ALTER DEFAULT PRIVILEGES IN SCHEMA rms_gateway GRANT ALL ON TABLES TO rms_gateway;
ALTER DEFAULT PRIVILEGES IN SCHEMA rms_gateway GRANT ALL ON SEQUENCES TO rms_gateway;

