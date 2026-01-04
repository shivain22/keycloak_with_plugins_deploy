# Database Vendor Version & Driver Management Plan

## Requirements

1. **Version Management**:
   - Track database vendor versions (last 3 years)
   - Store version information in database
   - Allow version selection during tenant creation

2. **Driver JAR Management**:
   - Upload JDBC/R2DBC driver JARs
   - Store JARs with proper identification (vendor, version, type)
   - Load drivers dynamically at runtime
   - Use uploaded drivers for connection testing

3. **Storage**:
   - File system storage for JARs
   - Database entity to track driver metadata
   - Proper naming/organization

## Implementation Plan

### Backend

#### Phase 1: Database Schema
1. Create `database_vendor_versions` table
2. Create `database_drivers` table (stores JAR metadata)
3. Update `database_vendors` if needed

#### Phase 2: Entities & Repositories
1. `DatabaseVendorVersion` entity
2. `DatabaseDriver` entity
3. Repositories for both

#### Phase 3: File Storage Service
1. Service to store/retrieve driver JARs
2. Organized directory structure: `drivers/{vendor}/{version}/{type}/`
3. File naming: `{vendor}-{version}-{type}.jar`

#### Phase 4: Driver Loading Service
1. Dynamic classloader for driver JARs
2. Load driver classes at runtime
3. Cache loaded drivers

#### Phase 5: API Endpoints
1. CRUD for vendor versions
2. Upload driver JAR endpoint
3. List available drivers
4. Update connection test to use selected driver

### Frontend

#### Phase 1: Version Selection
1. Add version dropdown (filtered by vendor)
2. Show only last 3 years versions

#### Phase 2: Driver Upload
1. File upload component
2. Show uploaded drivers
3. Select driver for connection

#### Phase 3: Integration
1. Update tenant form with version/driver selection
2. Update connection test to use selected driver

