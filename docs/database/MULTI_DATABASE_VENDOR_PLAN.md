# Multi-Database Vendor Support - Implementation Plan

## Objective
Add support for multiple database vendors (Oracle, MySQL, PostgreSQL, MSSQL, DB2) in tenant creation, starting with vendor selection and storage.

## Supported Database Vendors

### Primary Vendors (To Implement)
1. **PostgreSQL** - ✅ Already supported
2. **MySQL** - To add
3. **Oracle** - To add
4. **MSSQL (SQL Server)** - To add
5. **DB2** - To add

### Additional Vendors (Consider for Future)
- **MariaDB** - Similar to MySQL, can reuse MySQL implementation
- **H2** - In-memory database (for testing)
- **HSQLDB** - In-memory database (for testing)

## Implementation Plan

### Phase 1: Backend - Database Vendor Storage

#### Step 1.1: Create DatabaseType Enum
**File**: `src/main/java/com/atparui/rms/service/dto/DatabaseType.java`
```java
public enum DatabaseType {
    POSTGRESQL("PostgreSQL", 5432, "postgresql"),
    MYSQL("MySQL", 3306, "mysql"),
    ORACLE("Oracle", 1521, "oracle"),
    MSSQL("Microsoft SQL Server", 1433, "mssql"),
    DB2("IBM DB2", 50000, "db2");
    
    // fields: displayName, defaultPort, driverKey
}
```

#### Step 1.2: Update Tenant Entity
**File**: `src/main/java/com/atparui/rms/domain/Tenant.java`
- Add field: `databaseType` (String) - Store enum value
- Migration: Add column `database_type VARCHAR(50)` to `tenants` table

#### Step 1.3: Update TenantService
**File**: `src/main/java/com/atparui/rms/service/TenantService.java`
- Modify `createConnectionFactory()` to check `databaseType` and create appropriate factory
- For now, keep PostgreSQL logic, add TODO for other types

#### Step 1.4: Create Database Migration
**File**: `src/main/resources/db/changelog/YYYYMMDDHHMM-add-database-type.xml`
- Add `database_type` column to tenants table
- Set default value to 'POSTGRESQL' for existing tenants

### Phase 2: Frontend - Database Vendor Selection

#### Step 2.1: Update Tenant Model
**File**: `src/main/webapp/app/modules/administration/tenant-management/tenant.model.ts`
- Add field: `databaseType?: string;`

#### Step 2.2: Create Database Type Enum/Constants
**File**: `src/main/webapp/app/modules/administration/tenant-management/database-type.model.ts`
```typescript
export enum DatabaseType {
  POSTGRESQL = 'POSTGRESQL',
  MYSQL = 'MYSQL',
  ORACLE = 'ORACLE',
  MSSQL = 'MSSQL',
  DB2 = 'DB2'
}

export const DATABASE_TYPES = [
  { value: DatabaseType.POSTGRESQL, label: 'PostgreSQL', defaultPort: 5432 },
  { value: DatabaseType.MYSQL, label: 'MySQL', defaultPort: 3306 },
  { value: DatabaseType.ORACLE, label: 'Oracle', defaultPort: 1521 },
  { value: DatabaseType.MSSQL, label: 'Microsoft SQL Server', defaultPort: 1433 },
  { value: DatabaseType.DB2, label: 'IBM DB2', defaultPort: 50000 }
];
```

#### Step 2.3: Update Tenant Creation Form
**File**: `src/main/webapp/app/modules/administration/tenant-management/tenant-management-update.component.ts`
- Add database type dropdown/select field
- Set default to PostgreSQL
- Show default port based on selection

#### Step 2.4: Update Tenant Form HTML
**File**: `src/main/webapp/app/modules/administration/tenant-management/tenant-management-update.component.html`
- Add database type selector
- Position it before database URL field

### Phase 3: API Updates

#### Step 3.1: Update TenantResource
**File**: `src/main/java/com/atparui/rms/web/rest/TenantResource.java`
- Ensure `databaseType` is accepted in POST/PUT requests
- No changes needed if using Tenant entity directly

#### Step 3.2: Add Database Type Validation
**File**: `src/main/java/com/atparui/rms/service/TenantService.java`
- Validate `databaseType` is one of supported values
- Set default to POSTGRESQL if not provided (backward compatibility)

### Phase 4: Testing

#### Step 4.1: Backend Tests
- Test Tenant entity with different database types
- Test database type validation
- Test default value assignment

#### Step 4.2: Frontend Tests
- Test database type selection in form
- Test form submission with different types
- Test default value

## Implementation Order

1. **Backend First** (Steps 1.1, 1.2, 1.4) - Add database type storage
2. **Frontend Second** (Steps 2.1, 2.2, 2.3, 2.4) - Add UI selection
3. **Integration** (Steps 3.1, 3.2) - Wire everything together
4. **Testing** (Step 4) - Verify it works

## Next Steps (After This Phase)

Once database type is stored and selectable:
- Implement database-specific connection factories
- Implement database-specific provisioning logic
- Add database-specific validation
- Support existing databases (not just auto-create)

## Files to Modify

### Backend
1. `Tenant.java` - Add databaseType field
2. `TenantService.java` - Add validation, update connection factory (placeholder)
3. New: `DatabaseType.java` - Enum definition
4. New: Liquibase migration file

### Frontend
1. `tenant.model.ts` - Add databaseType field
2. New: `database-type.model.ts` - Constants/enum
3. `tenant-management-update.component.ts` - Add form field
4. `tenant-management-update.component.html` - Add UI element

## Estimated Time
- Backend changes: 2-3 hours
- Frontend changes: 2-3 hours
- Testing: 1-2 hours
- **Total: 1 day**

