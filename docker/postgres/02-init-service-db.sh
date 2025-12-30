#!/bin/bash
set -e

# Create rms_service database if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE rms_service'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'rms_service')\gexec
EOSQL

# Grant privileges to rms_service user on the database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE rms_service TO rms_service;
EOSQL

# Connect to rms_service database and grant schema privileges
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "rms_service" <<-EOSQL
    -- Ensure public schema exists (should exist by default, but ensure it)
    CREATE SCHEMA IF NOT EXISTS public;
    
    -- Grant usage and create privileges on public schema
    GRANT USAGE ON SCHEMA public TO rms_service;
    GRANT CREATE ON SCHEMA public TO rms_service;
    
    -- Grant privileges on existing objects
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO rms_service;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rms_service;
    
    -- Set default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO rms_service;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO rms_service;
    
    -- Set default schema for the user (optional, but helps)
    ALTER USER rms_service SET search_path TO public;
EOSQL
