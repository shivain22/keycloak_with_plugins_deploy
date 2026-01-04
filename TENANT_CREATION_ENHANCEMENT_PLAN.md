# Tenant Creation Enhancement Plan

## Overview
This document outlines a comprehensive phased approach to enhance the tenant creation system with:
1. **Multi-Database Support**: Support for MySQL, Oracle, DB2, PostgreSQL, and MSSQL
2. **Database Connectivity Validation**: Verify database connections before tenant creation
3. **Custom Domain Support**: Integration with DNS providers (Route53, Cloudflare, etc.) for custom domain management
4. **Enhanced Frontend**: Multi-step wizard for tenant creation with database and domain configuration

---

## Current State Analysis

### Current Implementation
- **Database**: Only PostgreSQL supported, hardcoded in `DatabaseProvisioningService`
- **Domain**: Only subdomain of `atparui.com` supported
- **Database Creation**: Automatic creation with fixed naming pattern (`rms_{tenantId}`)
- **Frontend**: Basic tenant creation form with minimal fields
- **Validation**: No database connectivity checks before creation

### Key Files
- Backend:
  - `TenantService.java` - Main tenant creation logic
  - `DatabaseProvisioningService.java` - Database provisioning (PostgreSQL only)
  - `TenantResource.java` - REST API endpoints
  - `Tenant.java` - Domain entity
- Frontend:
  - `tenant.model.ts` - Tenant interface
  - Tenant management components (to be located)

---

## Phase 1: Database Abstraction Layer (Backend Foundation)

### Objective
Create a database-agnostic abstraction layer to support multiple RDBMS types.

### Tasks

#### 1.1: Create Database Type Enum
**File**: `src/main/java/com/atparui/rms/service/dto/DatabaseType.java`
- Enum values: `POSTGRESQL`, `MYSQL`, `ORACLE`, `DB2`, `MSSQL`
- Include connection URL patterns, default ports, driver class names

#### 1.2: Create Database Connection DTO
**File**: `src/main/java/com/atparui/rms/service/dto/DatabaseConnectionDTO.java`
- Fields:
  - `databaseType` (DatabaseType enum)
  - `host` (String)
  - `port` (Integer)
  - `databaseName` (String)
  - `schemaName` (String) - Optional for databases that support schemas
  - `username` (String)
  - `password` (String)
  - `useSSL` (Boolean)
  - `additionalProperties` (Map<String, String>) - For database-specific options

#### 1.3: Create Database Connection Factory Interface
**File**: `src/main/java/com/atparui/rms/service/database/DatabaseConnectionFactory.java`
- Interface for creating database connections
- Methods:
  - `createConnection(DatabaseConnectionDTO config)` - Returns Connection
  - `testConnection(DatabaseConnectionDTO config)` - Returns boolean
  - `getDriverClassName(DatabaseType type)` - Returns String

#### 1.4: Implement Database-Specific Factories
**Files**:
- `PostgreSQLConnectionFactory.java`
- `MySQLConnectionFactory.java`
- `OracleConnectionFactory.java`
- `DB2ConnectionFactory.java`
- `MSSQLConnectionFactory.java`

Each factory implements:
- JDBC connection creation
- Connection testing/validation
- Database-specific URL building
- Driver class loading

#### 1.5: Create Database Provisioning Interface
**File**: `src/main/java/com/atparui/rms/service/database/DatabaseProvisioner.java`
- Interface for database provisioning operations
- Methods:
  - `createDatabase(DatabaseConnectionDTO adminConfig, String databaseName)` - Returns boolean
  - `createUser(DatabaseConnectionDTO adminConfig, String username, String password)` - Returns boolean
  - `grantPrivileges(DatabaseConnectionDTO adminConfig, String databaseName, String username)` - Returns boolean
  - `testConnection(DatabaseConnectionDTO config)` - Returns boolean
  - `databaseExists(DatabaseConnectionDTO adminConfig, String databaseName)` - Returns boolean
  - `userExists(DatabaseConnectionDTO adminConfig, String username)` - Returns boolean

#### 1.6: Implement Database-Specific Provisioners
**Files**:
- `PostgreSQLProvisioner.java`
- `MySQLProvisioner.java`
- `OracleProvisioner.java`
- `DB2Provisioner.java`
- `MSSQLProvisioner.java`

Each provisioner handles:
- Database creation (if supported)
- User/schema creation
- Privilege granting
- Database-specific SQL syntax

#### 1.7: Update Tenant Entity
**File**: `src/main/java/com/atparui/rms/domain/Tenant.java`
- Add fields:
  - `databaseType` (String) - Store database type enum value
  - `databaseHost` (String) - Store database host
  - `databasePort` (Integer) - Store database port
  - `databaseName` (String) - Store database name (may differ from auto-generated)
  - `databaseSchema` (String) - Store schema name (for Oracle, DB2, MSSQL)
  - `databaseSslEnabled` (Boolean) - SSL configuration
  - `databaseAdditionalProperties` (String) - JSON string for additional properties

**Migration**: Create Liquibase changeset to add new columns to `tenants` table

#### 1.8: Create Database Connection Validator Service
**File**: `src/main/java/com/atparui/rms/service/DatabaseConnectionValidatorService.java`
- Service to validate database connections before tenant creation
- Methods:
  - `validateConnection(DatabaseConnectionDTO config)` - Returns `ValidationResult`
  - `checkDatabaseExists(DatabaseConnectionDTO adminConfig, String databaseName)` - Returns boolean
  - `checkUserExists(DatabaseConnectionDTO adminConfig, String username)` - Returns boolean
  - `testAdminCredentials(DatabaseConnectionDTO adminConfig)` - Returns boolean

**ValidationResult DTO**:
- `isValid` (boolean)
- `errorMessage` (String)
- `connectionDetails` (Map<String, Object>)

### Dependencies
- Add database drivers to `pom.xml`:
  - MySQL: `mysql-connector-java`
  - Oracle: `ojdbc8` (or appropriate version)
  - DB2: `db2jcc4`
  - MSSQL: `mssql-jdbc`

### Testing
- Unit tests for each database factory
- Integration tests for connection validation
- Mock tests for provisioning operations

### Estimated Time: 2-3 weeks

---

## Phase 2: Enhanced Database Provisioning Service

### Objective
Refactor `DatabaseProvisioningService` to support multiple database types and handle existing databases.

### Tasks

#### 2.1: Refactor DatabaseProvisioningService
**File**: `src/main/java/com/atparui/rms/service/DatabaseProvisioningService.java`
- Replace hardcoded PostgreSQL logic with database-agnostic approach
- Use `DatabaseProvisioner` interface based on database type
- Support two modes:
  1. **Auto-create mode**: Create database/user if they don't exist (requires admin credentials)
  2. **Existing database mode**: Use existing database/user (validate connectivity)

#### 2.2: Add Database Provisioning Context
**File**: `src/main/java/com/atparui/rms/service/dto/DatabaseProvisioningContext.java`
- Fields:
  - `provisioningMode` (enum: `AUTO_CREATE`, `USE_EXISTING`)
  - `adminConfig` (DatabaseConnectionDTO) - Admin credentials for auto-create
  - `targetConfig` (DatabaseConnectionDTO) - Target database configuration
  - `databaseExists` (boolean)
  - `userExists` (boolean)
  - `hasAdminAccess` (boolean)

#### 2.3: Update Tenant Creation Flow
**File**: `src/main/java/com/atparui/rms/service/TenantService.java`
- Modify `createTenantWithKeycloak()` to:
  1. Accept `DatabaseProvisioningContext` instead of auto-creating
  2. Validate database connection before proceeding
  3. Create database/user only if in auto-create mode and they don't exist
  4. Store database type and connection details in Tenant entity

#### 2.4: Add Database Connectivity Endpoint
**File**: `src/main/java/com/atparui/rms/web/rest/TenantResource.java`
- New endpoint: `POST /api/tenants/validate-database`
- Request body: `DatabaseConnectionDTO`
- Response: `ValidationResult`
- Purpose: Allow frontend to test database connection before tenant creation

#### 2.5: Update R2DBC Connection Factory Creation
**File**: `src/main/java/com/atparui/rms/service/TenantService.java`
- Modify `createConnectionFactory()` to support multiple database types
- Use appropriate R2DBC driver based on database type:
  - PostgreSQL: `io.r2dbc.postgresql`
  - MySQL: `io.asyncer:r2dbc-mysql`
  - MSSQL: `io.r2dbc:r2dbc-mssql`
  - Oracle: `io.r2dbc:r2dbc-oracle` (if available)
  - DB2: Custom implementation or JDBC wrapper

### Dependencies
- Add R2DBC drivers to `pom.xml`:
  - MySQL: `io.asyncer:r2dbc-mysql`
  - MSSQL: `io.r2dbc:r2dbc-mssql`
  - Oracle: Check availability
  - DB2: May require custom implementation

### Testing
- Test auto-create mode for each database type
- Test existing database mode
- Test connection validation
- Test error handling and rollback

### Estimated Time: 2 weeks

---

## Phase 3: DNS Provider Integration (Backend)

### Objective
Integrate with DNS providers to support custom domain management.

### Tasks

#### 3.1: Create DNS Provider Interface
**File**: `src/main/java/com/atparui/rms/service/dns/DnsProvider.java`
- Interface for DNS operations
- Methods:
  - `createSubdomain(String domain, String subdomain, String targetIp)` - Returns boolean
  - `deleteSubdomain(String domain, String subdomain)` - Returns boolean
  - `updateSubdomain(String domain, String subdomain, String targetIp)` - Returns boolean
  - `verifyDomainOwnership(String domain)` - Returns boolean
  - `listSubdomains(String domain)` - Returns List<String>

#### 3.2: Implement DNS Providers
**Files**:
- `Route53DnsProvider.java` - AWS Route53 integration
- `CloudflareDnsProvider.java` - Cloudflare API integration
- `GoogleCloudDnsProvider.java` - Google Cloud DNS integration
- `GenericDnsProvider.java` - Generic DNS API (for other providers)

Each provider:
- Uses provider-specific SDK/API
- Handles authentication (API keys, OAuth, etc.)
- Implements DNS record creation/update/deletion
- Handles error cases

#### 3.3: Create DNS Provider Factory
**File**: `src/main/java/com/atparui/rms/service/dns/DnsProviderFactory.java`
- Factory to create appropriate DNS provider based on provider type
- Supports configuration via properties file or environment variables

#### 3.4: Create Domain Configuration DTO
**File**: `src/main/java/com/atparui/rms/service/dto/DomainConfigurationDTO.java`
- Fields:
  - `domainType` (enum: `SUBDOMAIN_ATPARUI`, `CUSTOM_DOMAIN`)
  - `domain` (String) - Full domain or subdomain
  - `dnsProvider` (enum: `ROUTE53`, `CLOUDFLARE`, `GOOGLE_CLOUD`, `MANUAL`)
  - `dnsProviderConfig` (Map<String, String>) - Provider-specific configuration
  - `targetIp` (String) - IP address or CNAME target
  - `sslEnabled` (Boolean) - Whether SSL certificate is needed

#### 3.5: Create Domain Management Service
**File**: `src/main/java/com/atparui/rms/service/DomainManagementService.java`
- Service to manage domain configuration
- Methods:
  - `createSubdomain(DomainConfigurationDTO config)` - Returns boolean
  - `deleteSubdomain(String domain)` - Returns boolean
  - `verifyDomainConfiguration(DomainConfigurationDTO config)` - Returns ValidationResult
  - `getSslCertificateStatus(String domain)` - Returns SslCertificateStatus

#### 3.6: Update Tenant Entity
**File**: `src/main/java/com/atparui/rms/domain/Tenant.java`
- Add fields:
  - `domainType` (String) - Enum value
  - `customDomain` (String) - Custom domain if applicable
  - `dnsProvider` (String) - DNS provider type
  - `dnsProviderConfig` (String) - JSON string for provider config

**Migration**: Create Liquibase changeset to add new columns

#### 3.7: Integrate Domain Management into Tenant Creation
**File**: `src/main/java/com/atparui/rms/service/TenantService.java`
- Add domain creation step in tenant creation flow
- Handle both subdomain (atparui.com) and custom domain cases
- For custom domains: Create DNS record via provider API
- For subdomains: Use existing logic or simple DNS update

#### 3.8: Add Domain Validation Endpoint
**File**: `src/main/java/com/atparui/rms/web/rest/TenantResource.java`
- New endpoint: `POST /api/tenants/validate-domain`
- Request body: `DomainConfigurationDTO`
- Response: `ValidationResult`
- Purpose: Verify domain configuration before tenant creation

### Dependencies
- AWS SDK for Route53: `software.amazon.awssdk:route53`
- Cloudflare API client: Custom or use `com.cloudflare:cloudflare-java`
- Google Cloud DNS: `com.google.cloud:google-cloud-dns`

### Configuration
- Add DNS provider credentials to `application.yml` or environment variables
- Support multiple provider configurations

### Testing
- Unit tests for each DNS provider
- Integration tests with test DNS zones
- Mock tests for DNS operations

### Estimated Time: 2-3 weeks

---

## Phase 4: Enhanced Tenant Creation API (Backend)

### Objective
Create comprehensive API endpoints for multi-step tenant creation with validation.

### Tasks

#### 4.1: Create Tenant Creation Request DTO
**File**: `src/main/java/com/atparui/rms/service/dto/TenantCreationRequestDTO.java`
- Comprehensive DTO for tenant creation
- Fields:
  - Basic tenant info (name, tenantKey, tenantId)
  - Database configuration (DatabaseConnectionDTO)
  - Database provisioning context (DatabaseProvisioningContext)
  - Domain configuration (DomainConfigurationDTO)
  - Keycloak configuration (realm name, client settings)
  - Additional settings

#### 4.2: Create Tenant Creation Response DTO
**File**: `src/main/java/com/atparui/rms/service/dto/TenantCreationResponseDTO.java`
- Response DTO with creation status
- Fields:
  - `tenant` (Tenant)
  - `creationStatus` (enum: `SUCCESS`, `PARTIAL`, `FAILED`)
  - `stepsCompleted` (List<String>)
  - `errors` (List<String>)
  - `warnings` (List<String>)

#### 4.3: Refactor Tenant Creation Endpoint
**File**: `src/main/java/com/atparui/rms/web/rest/TenantResource.java`
- Update `createTenant()` to accept `TenantCreationRequestDTO`
- Implement multi-step validation:
  1. Validate tenant key/ID uniqueness
  2. Validate database connection
  3. Validate domain configuration
  4. Create tenant entity
  5. Provision database (if needed)
  6. Create domain/DNS records (if needed)
  7. Create Keycloak realm
  8. Return comprehensive response

#### 4.4: Add Step-by-Step Validation Endpoints
**File**: `src/main/java/com/atparui/rms/web/rest/TenantResource.java`
- `POST /api/tenants/validate-tenant-key` - Check tenant key availability
- `POST /api/tenants/validate-database` - Validate database connection
- `POST /api/tenants/validate-domain` - Validate domain configuration
- `POST /api/tenants/validate-all` - Validate all configurations at once

#### 4.5: Add Tenant Creation Status Endpoint
**File**: `src/main/java/com/atparui/rms/web/rest/TenantResource.java`
- `GET /api/tenants/{tenantId}/creation-status` - Get creation status (for async operations)

#### 4.6: Implement Async Tenant Creation (Optional)
- For long-running operations, support async tenant creation
- Use Spring's `@Async` or reactive approach
- Return job ID for status tracking

### Testing
- Integration tests for complete tenant creation flow
- Test each validation endpoint
- Test error scenarios and rollback

### Estimated Time: 1-2 weeks

---

## Phase 5: Enhanced Frontend - Multi-Step Wizard

### Objective
Create a comprehensive multi-step wizard for tenant creation with database and domain configuration.

### Tasks

#### 5.1: Create Tenant Creation Wizard Component
**File**: `src/main/webapp/app/modules/administration/tenant-management/tenant-creation-wizard.component.ts`
- Multi-step wizard component
- Steps:
  1. **Basic Information**: Tenant name, key, ID
  2. **Database Configuration**: Database type, connection details, provisioning mode
  3. **Domain Configuration**: Domain type, custom domain setup, DNS provider
  4. **Keycloak Configuration**: Realm name, client settings (optional, can use defaults)
  5. **Review & Confirm**: Summary of all configurations
  6. **Creation Progress**: Show creation steps and status

#### 5.2: Create Database Configuration Component
**File**: `src/main/webapp/app/modules/administration/tenant-management/database-config.component.ts`
- Component for database configuration step
- Features:
  - Database type selector (PostgreSQL, MySQL, Oracle, DB2, MSSQL)
  - Connection form (host, port, database name, schema, credentials)
  - Provisioning mode selector:
    - **Auto-create**: Requires admin credentials, creates DB/user
    - **Use existing**: Requires target DB credentials, validates connection
  - Connection test button (calls validation API)
  - Form validation

#### 5.3: Create Domain Configuration Component
**File**: `src/main/webapp/app/modules/administration/tenant-management/domain-config.component.ts`
- Component for domain configuration step
- Features:
  - Domain type selector:
    - **Subdomain (atparui.com)**: Simple subdomain input
    - **Custom Domain**: Full domain configuration
  - For custom domain:
    - Domain input
    - DNS provider selector (Route53, Cloudflare, Google Cloud, Manual)
    - DNS provider credentials form (if needed)
    - Domain verification button
  - Domain validation status display

#### 5.4: Create Tenant Creation Service
**File**: `src/main/webapp/app/modules/administration/tenant-management/tenant-creation.service.ts`
- Service to handle tenant creation API calls
- Methods:
  - `validateTenantKey(tenantKey: string)` - Observable<ValidationResult>
  - `validateDatabase(config: DatabaseConnectionDTO)` - Observable<ValidationResult>
  - `validateDomain(config: DomainConfigurationDTO)` - Observable<ValidationResult>
  - `createTenant(request: TenantCreationRequestDTO)` - Observable<TenantCreationResponseDTO>
  - `getCreationStatus(tenantId: string)` - Observable<CreationStatus>

#### 5.5: Update Tenant Model
**File**: `src/main/webapp/app/modules/administration/tenant-management/tenant.model.ts`
- Add new fields for database and domain configuration
- Create DTOs for:
  - `DatabaseConnectionDTO`
  - `DomainConfigurationDTO`
  - `TenantCreationRequestDTO`
  - `ValidationResult`

#### 5.6: Create Progress Indicator Component
**File**: `src/main/webapp/app/modules/administration/tenant-management/creation-progress.component.ts`
- Component to show tenant creation progress
- Displays:
  - Current step
  - Completed steps
  - Errors/warnings
  - Estimated time remaining

#### 5.7: Add Form Validation
- Implement comprehensive form validation
- Real-time validation feedback
- Disable next step until current step is valid
- Show connection test results

#### 5.8: Add Error Handling
- Display validation errors clearly
- Handle API errors gracefully
- Show rollback status if creation fails
- Provide retry options

### UI/UX Considerations
- Use Angular Material or similar for wizard UI
- Progress indicator at top
- Step navigation (Next/Back buttons)
- Save draft functionality (optional)
- Responsive design

### Testing
- Unit tests for components
- E2E tests for complete wizard flow
- Test form validation
- Test API integration

### Estimated Time: 3-4 weeks

---

## Phase 6: Integration & Testing

### Objective
Integrate all components, perform comprehensive testing, and handle edge cases.

### Tasks

#### 6.1: End-to-End Integration
- Integrate all phases
- Test complete tenant creation flow
- Test with each database type
- Test with each DNS provider
- Test error scenarios

#### 6.2: Performance Testing
- Test tenant creation with large databases
- Test concurrent tenant creation
- Optimize database connection pooling
- Optimize DNS API calls

#### 6.3: Security Testing
- Validate input sanitization
- Test SQL injection prevention
- Test credential storage security
- Test DNS provider API security

#### 6.4: Documentation
- API documentation (Swagger/OpenAPI)
- User guide for tenant creation
- Admin guide for DNS provider setup
- Database setup guides for each DB type

#### 6.5: Error Handling & Rollback
- Comprehensive error handling
- Proper rollback for all failure scenarios
- Logging and monitoring
- Alerting for critical failures

### Estimated Time: 2 weeks

---

## Phase 7: Deployment & Migration

### Objective
Deploy enhancements and migrate existing tenants if needed.

### Tasks

#### 7.1: Database Migration
- Create Liquibase changesets for new columns
- Migrate existing tenant data
- Add default values for existing tenants

#### 7.2: Configuration Updates
- Update environment variables
- Configure DNS provider credentials
- Update nginx configuration for custom domains

#### 7.3: Deployment Strategy
- Deploy backend changes first
- Deploy frontend changes
- Gradual rollout (feature flags if needed)
- Monitor for issues

#### 7.4: Rollback Plan
- Document rollback procedures
- Test rollback scenarios
- Keep previous version available

### Estimated Time: 1 week

---

## Implementation Priority

### High Priority (Must Have)
1. **Phase 1**: Database Abstraction Layer - Foundation for everything
2. **Phase 2**: Enhanced Database Provisioning - Core functionality
3. **Phase 4**: Enhanced Tenant Creation API - Backend API
4. **Phase 5**: Enhanced Frontend - User-facing functionality

### Medium Priority (Should Have)
5. **Phase 3**: DNS Provider Integration - Important for custom domains
6. **Phase 6**: Integration & Testing - Quality assurance

### Low Priority (Nice to Have)
7. **Phase 7**: Deployment & Migration - Can be done incrementally

---

## Parallel Development Opportunities

### Can Be Developed in Parallel
1. **Database Abstraction (Phase 1)** and **DNS Provider Integration (Phase 3)** - Independent
2. **Frontend Components (Phase 5)** - Can start after Phase 4 API is defined
3. **Database-Specific Implementations** - Can be done in parallel by different developers

### Sequential Dependencies
1. **Phase 2** depends on **Phase 1**
2. **Phase 4** depends on **Phase 2** and **Phase 3**
3. **Phase 5** depends on **Phase 4**
4. **Phase 6** depends on all previous phases

---

## Risk Mitigation

### Technical Risks
1. **Database Driver Compatibility**: Test with multiple versions
2. **DNS Provider API Changes**: Abstract provider interface, version APIs
3. **R2DBC Driver Availability**: May need custom implementations for some databases
4. **Performance**: Implement connection pooling, async operations

### Business Risks
1. **Complexity**: Break into small, testable phases
2. **User Adoption**: Provide clear UI/UX, documentation
3. **Support**: Train support team on new features

---

## Success Criteria

### Functional
- ✅ Support all 5 database types (PostgreSQL, MySQL, Oracle, DB2, MSSQL)
- ✅ Validate database connections before tenant creation
- ✅ Support custom domains with DNS provider integration
- ✅ Multi-step wizard for tenant creation
- ✅ Comprehensive error handling and rollback

### Non-Functional
- ✅ Tenant creation completes in < 2 minutes (for auto-create mode)
- ✅ Database connection validation in < 5 seconds
- ✅ Support 100+ concurrent tenant creations
- ✅ 99.9% success rate for tenant creation

---

## Timeline Estimate

### Conservative Estimate
- **Phase 1**: 3 weeks
- **Phase 2**: 2 weeks
- **Phase 3**: 3 weeks
- **Phase 4**: 2 weeks
- **Phase 5**: 4 weeks
- **Phase 6**: 2 weeks
- **Phase 7**: 1 week

**Total**: ~17 weeks (~4 months) with sequential development

### Optimistic Estimate (with Parallel Development)
- **Phase 1 & 3** (parallel): 3 weeks
- **Phase 2**: 2 weeks
- **Phase 4**: 2 weeks
- **Phase 5**: 4 weeks
- **Phase 6**: 2 weeks
- **Phase 7**: 1 week

**Total**: ~14 weeks (~3.5 months) with parallel development

---

## Next Steps

1. **Review and Approve Plan**: Get stakeholder approval
2. **Prioritize Phases**: Decide on implementation order
3. **Assign Resources**: Allocate developers
4. **Set Up Development Environment**: Prepare for multi-database testing
5. **Start Phase 1**: Begin database abstraction layer implementation

---

## Questions to Resolve

1. **Database Support Priority**: Which databases should be supported first?
2. **DNS Provider Priority**: Which DNS providers are most important?
3. **Existing Tenant Migration**: How to handle existing tenants with old structure?
4. **SSL Certificate Management**: Automatic SSL certificate provisioning (Let's Encrypt)?
5. **Admin Credentials Storage**: How to securely store DNS provider credentials?
6. **Async vs Sync**: Should tenant creation be async for long operations?

---

## Appendix: Database-Specific Considerations

### PostgreSQL
- ✅ Full support (current implementation)
- R2DBC driver: `io.r2dbc:r2dbc-postgresql`
- Schema support: Yes

### MySQL
- R2DBC driver: `io.asyncer:r2dbc-mysql`
- Schema support: Limited (databases are schemas)
- User creation: Standard SQL

### Oracle
- R2DBC driver: Check availability, may need custom
- Schema support: Yes (users are schemas)
- User creation: `CREATE USER` with tablespace

### DB2
- R2DBC driver: May need custom implementation
- Schema support: Yes
- User creation: `CREATE USER` with bufferpool

### MSSQL
- R2DBC driver: `io.r2dbc:r2dbc-mssql`
- Schema support: Yes
- User creation: `CREATE LOGIN` and `CREATE USER`

---

## Appendix: DNS Provider Considerations

### AWS Route53
- API: AWS SDK
- Authentication: IAM roles or access keys
- Rate limits: High
- Cost: Pay per hosted zone and queries

### Cloudflare
- API: REST API
- Authentication: API token or global API key
- Rate limits: 1200 requests per 5 minutes
- Cost: Free tier available

### Google Cloud DNS
- API: Google Cloud DNS API
- Authentication: Service account JSON
- Rate limits: 1000 requests per 100 seconds
- Cost: Pay per zone and queries

### Manual DNS
- No API integration
- Admin must manually create DNS records
- System provides instructions for DNS setup

