#!/bin/bash
set -e

# Create rms_gateway database if it doesn't exist
# Note: CREATE DATABASE cannot run inside a transaction, so we use a shell command
echo "==> Initializing rms_gateway database..."

# Check if database exists by querying pg_database
DB_EXISTS=$(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "SELECT 1 FROM pg_database WHERE datname='rms_gateway'" 2>/dev/null || echo "")

if [ "$DB_EXISTS" = "1" ]; then
    echo "✅ rms_gateway database already exists"
else
    echo "Creating rms_gateway database..."
    # CREATE DATABASE must be run outside of a transaction block
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE DATABASE rms_gateway;
EOSQL
    if [ $? -eq 0 ]; then
        echo "✅ rms_gateway database created successfully"
    else
        echo "ERROR: Failed to create rms_gateway database" >&2
        exit 1
    fi
fi

# Grant privileges to rms_gateway user on the database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE rms_gateway TO rms_gateway;
EOSQL

# Connect to rms_gateway database and grant privileges on public schema
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "rms_gateway" <<-EOSQL
    -- Ensure public schema exists (should exist by default, but ensure it)
    CREATE SCHEMA IF NOT EXISTS public;
    
    -- Grant usage and create privileges on public schema
    GRANT USAGE ON SCHEMA public TO rms_gateway;
    GRANT CREATE ON SCHEMA public TO rms_gateway;
    
    -- Grant privileges on existing objects
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO rms_gateway;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rms_gateway;
    
    -- Set default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO rms_gateway;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO rms_gateway;
    
    -- Set default schema for the user
    ALTER USER rms_gateway SET search_path TO public;
EOSQL

echo "✅ rms_gateway database initialized successfully"

