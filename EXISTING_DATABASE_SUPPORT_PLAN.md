# Existing Database Support - Implementation Plan

## Overview
Allow tenants to use existing databases or create new ones, with connection testing before tenant creation.

## Requirements

### Backend
1. Add fields to Tenant entity:
   - `databaseProvisioningMode` (enum: AUTO_CREATE, USE_EXISTING)
   - `databaseHost` (String)
   - `databasePort` (Integer)
   - `databaseName` (String) - separate from URL
   - Keep existing: `databaseUrl`, `databaseUsername`, `databasePassword`, `schemaName`

2. Create Database Connection Test Service:
   - Test JDBC connection
   - Support all vendor types
   - Return validation result

3. Create REST endpoint:
   - `POST /api/tenants/test-database-connection` - Test connection

4. Update TenantService:
   - Handle both modes (auto-create vs existing)
   - Generate URL from host/port/database using vendor template

### Frontend
1. Multi-step form:
   - Step 1: Basic info + Database vendor selection
   - Step 2: Database provisioning mode (Create new / Use existing)
   - Step 3a: If existing - Connection details form
   - Step 3b: Connection test button
   - Step 4: Review and submit

2. Connection test:
   - Show loading state
   - Display success/error message
   - Disable submit until test passes

## Implementation Steps

1. Update Tenant entity with new fields
2. Create database migration
3. Create connection test DTO
4. Create connection test service
5. Create connection test endpoint
6. Update TenantService to handle both modes
7. Update frontend form with multi-step wizard
8. Add connection test UI

