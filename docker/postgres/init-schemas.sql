-- Initialize schemas for Gateway and Service
-- This script runs automatically on first PostgreSQL initialization

-- Create schema for Gateway
CREATE SCHEMA IF NOT EXISTS gateway;

-- Create schema for Service
CREATE SCHEMA IF NOT EXISTS rms_service;

-- Grant privileges to the database user
GRANT ALL PRIVILEGES ON SCHEMA gateway TO rms;
GRANT ALL PRIVILEGES ON SCHEMA rms_service TO rms;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA gateway GRANT ALL ON TABLES TO rms;
ALTER DEFAULT PRIVILEGES IN SCHEMA gateway GRANT ALL ON SEQUENCES TO rms;
ALTER DEFAULT PRIVILEGES IN SCHEMA rms_service GRANT ALL ON TABLES TO rms;
ALTER DEFAULT PRIVILEGES IN SCHEMA rms_service GRANT ALL ON SEQUENCES TO rms;

