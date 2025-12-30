#!/bin/bash
set -e

# Create rms_service database if it doesn't exist
# Note: CREATE DATABASE cannot run inside a transaction, so we use a shell command
echo "==> Initializing rms_service database..."

# Check if database exists by querying pg_database
DB_EXISTS=$(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_database WHERE datname='rms_service'" 2>/dev/null || echo "")

if [ "$DB_EXISTS" = "1" ]; then
    echo "✅ rms_service database already exists"
else
    echo "Creating rms_service database..."
    # CREATE DATABASE must be run outside of a transaction block
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE DATABASE rms_service;
EOSQL
    if [ $? -eq 0 ]; then
        echo "✅ rms_service database created successfully"
    else
        echo "ERROR: Failed to create rms_service database" >&2
        exit 1
    fi
fi

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

echo "✅ rms_service database initialized successfully"
