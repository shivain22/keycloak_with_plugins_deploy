# ATPAR SaaS Platform Architecture Summary

## Vision

A multi-product SaaS platform offering applications like **Restaurant Management System (RMS)**, **Neo Banking**, etc. Customers can demo, register, and get their own branded web/mobile apps deployed with subscription-based pricing.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           ATPAR SaaS PLATFORM                                │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐    ┌─────────────────────────────────────────────────────┐  │
│  │  KEYCLOAK   │    │              GATEWAY (Central)                      │  │
│  │             │    │  • Platform Management (RMS, Neo, etc.)             │  │
│  │ ┌─────────┐ │    │  • Tenant Management (CRUD, provisioning)           │  │
│  │ │ atpar-  │ │    │  • Database Management (vendors, drivers)           │  │
│  │ │ infra   │ │◄───│  • Keycloak Realm Management                        │  │
│  │ └─────────┘ │    │  • Multi-tenant DB routing                          │  │
│  │             │    └─────────────────────────────────────────────────────┘  │
│  │ ┌─────────┐ │                           │                                 │
│  │ │ gateway │ │                           │ Creates/Manages                 │
│  │ └─────────┘ │                           ▼                                 │
│  │             │    ┌─────────────────────────────────────────────────────┐  │
│  │ ┌─────────┐ │    │              MICROSERVICES                          │  │
│  │ │ tenant  │ │◄───│  ┌───────────────┐  ┌───────────────┐               │  │
│  │ │ realms  │ │    │  │  rms-service  │  │  neo-service  │  ...          │  │
│  │ │(dynamic)│ │    │  │  (per tenant) │  │  (per tenant) │               │  │
│  │ └─────────┘ │    │  └───────────────┘  └───────────────┘               │  │
│  └─────────────┘    └─────────────────────────────────────────────────────┘  │
│                                            │                                 │
│                                            │ Consumes                        │
│                                            ▼                                 │
│       ┌─────────────────────────────────────────────────────────────────┐    │
│       │              TENANT APPLICATIONS (Per-tenant repos)             │    │
│       │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │    │
│       │  │ rms-web-taj     │  │ rms-web-marriott│  │ rms-web-xxx     │  │    │
│       │  │ rms-mobile-taj  │  │ rms-mobile-...  │  │ rms-mobile-xxx  │  │    │
│       │  └─────────────────┘  └─────────────────┘  └─────────────────┘  │    │
│       └─────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Naming Conventions

### Keycloak Realms

| Realm | Purpose | Users |
|-------|---------|-------|
| `atpar-infra` | Infrastructure tools (Jenkins, Consul, Grafana) | DevOps team |
| `gateway` | SaaS Gateway admin panel | Platform admins |
| `{tenant-key}-realm` | Tenant authentication | Tenant end-users |

### Entities

| Entity | Description | Example |
|--------|-------------|---------|
| **Platform** | A SaaS product offering | RMS, Neo Banking |
| **Tenant** | A customer's deployment | Taj Restaurant, HDFC Bank |
| **TenantClient** | OAuth clients per tenant | taj-web, taj-mobile, taj-service |

### Identifiers

| Identifier | Format | Example | Usage |
|------------|--------|---------|-------|
| `tenantKey` | lowercase, alphanumeric, hyphens | `taj`, `marriott-india` | URL-safe, subdomain |
| `tenantId` | Same as tenantKey or UUID | `taj` or `uuid` | Internal reference |
| `platformPrefix` | 2-10 char uppercase | `RMS`, `NEO` | Platform identification |

### URLs

| Type | Pattern | Example |
|------|---------|---------|
| Tenant Web App | `{tenant-key}.rms.atparui.com` | `taj.rms.atparui.com` |
| Custom Domain | `app.{customer-domain}` | `app.tajrestaurant.com` |
| API Gateway | `api.atparui.com` | - |
| Auth | `auth.atparui.com/realms/{tenant-key}-realm` | - |

### Git Repositories

| Repo | Format | Example |
|------|--------|---------|
| Web Template | `{platform}-web-template` | `rms-web-template` |
| Mobile Template | `{platform}-mobile-template` | `rms-mobile-template` |
| Tenant Web | `{platform}-web-{tenant-key}` | `rms-web-taj` |
| Tenant Mobile | `{platform}-mobile-{tenant-key}` | `rms-mobile-taj` |

### Database

| Type | Format | Example |
|------|--------|---------|
| Platform Shared DB | `{platform}_platform` | `rms_platform` |
| Tenant DB/Schema | `{platform}_{tenant_key}` | `rms_taj` |

---

## Technology Stack

### Backend

| Component | Technology |
|-----------|------------|
| Gateway | Spring Boot 3.4 + WebFlux (JHipster) |
| Microservices | Spring Boot 3.4 + WebFlux |
| Database | PostgreSQL (R2DBC for reactive) |
| Service Discovery | Consul |
| API Gateway | Spring Cloud Gateway |
| Message Broker | Kafka |
| Search | Elasticsearch |

### Frontend

| Component | Technology |
|-----------|------------|
| Web Apps | Next.js 14+ (App Router) |
| Mobile Apps | React Native or Flutter |
| UI Framework | Tailwind CSS + shadcn/ui |
| State Management | Zustand or Redux Toolkit |

### Infrastructure

| Component | Technology |
|-----------|------------|
| Authentication | Keycloak |
| CI/CD | Jenkins + GitHub Actions |
| Container Runtime | Docker |
| Orchestration | Kubernetes (future) |
| Monitoring | Grafana + Prometheus |
| GitOps | ArgoCD (future) |

---

## Decisions Made

### ✅ Template Tenant
**Decision:** Skip for now  
**Reason:** Using Liquibase to create fresh schemas. Add template cloning later if needed for 50+ tenants.

### ✅ Per-Tenant Repos
**Decision:** Yes - separate repo per tenant  
**Reason:** 
- Premium clients can have repo access for customization
- Full isolation between tenants
- Independent deployment cycles

### ✅ Infrastructure Realm
**Decision:** Single `atpar-infra` realm for all DevOps tools  
**Reason:** 
- Unified user management for Jenkins, Consul, Grafana, etc.
- Single sign-on across all infrastructure
- Easier audit and access control

### ✅ Modular App Architecture
**Decision:** Clear separation of core/features/ui/tenant  
**Reason:**
- Core and features rarely change
- UI components are reusable
- Tenant config is isolated and safe to customize

---

## Current Implementation Status

### ✅ Completed

| Component | Status | Notes |
|-----------|--------|-------|
| Gateway (rms) | ✅ Complete | Tenant, Platform, TenantClient management |
| Keycloak + Plugins | ✅ Complete | Phone OTP, Custom Theme |
| RMS Service Entities | ✅ Complete | Full restaurant schema defined |
| Multi-tenant DB Routing | ✅ Complete | Dynamic connection per tenant |
| Keycloak Realm Auto-Creation | ✅ Complete | Creates realm on tenant creation |
| Database Driver Management | ✅ Complete | Dynamic JDBC/R2DBC drivers |
| `atpar-infra` Realm | ✅ Complete | Jenkins, Consul, Grafana clients |
| Documentation | ✅ Complete | Architecture, setup guides |

### 🟡 In Progress

| Component | Status | Notes |
|-----------|--------|-------|
| Tenant Web App Template | 🟡 Started | Next.js structure in `rms-web-app` |
| Jenkins Pipeline | 🟡 Setup | Basic Jenkinsfile exists |

### 🔴 Not Started

| Component | Priority | Notes |
|-----------|----------|-------|
| Mobile App Template | Medium | React Native or Flutter |
| Subscription/Billing | High | Plans, payments, usage |
| Self-Service Registration | High | Demo → Register → Deploy flow |
| Tenant Onboarding Automation | High | Fork repo, configure, deploy |
| Second Platform (Neo) | Low | Validate multi-platform architecture |

---

## File Structure Summary

```
ATPAR SaaS Workspace
│
├── keycloak_with_plugins_deploy/     # Keycloak + Infrastructure
│   ├── realm-import/
│   │   ├── atpar-infra-realm.json    # DevOps tools auth
│   │   └── gateway-realm.json        # SaaS admin auth
│   ├── providers/                     # Keycloak plugins
│   ├── themes/                        # Custom themes
│   └── *.md                          # Documentation
│
├── rms/                               # Gateway (Central SaaS Admin)
│   ├── src/main/java/.../domain/
│   │   ├── Platform.java             # SaaS products
│   │   ├── Tenant.java               # Customer deployments
│   │   ├── TenantClient.java         # OAuth clients
│   │   └── DatabaseVendor.java       # DB config
│   └── src/main/webapp/              # Admin UI
│
├── rms-service/                       # RMS Microservice
│   ├── src/main/java/.../domain/     # Restaurant entities
│   └── jdl/                          # JDL definitions
│
├── rms-auth-theme-plugin/            # Keycloak Theme
│   └── src/                          # React components
│
├── keycloak-phone-provider-parent/   # Phone OTP Plugin
│   └── keycloak-phone-provider/
│
└── rms-web-app/                      # Tenant Web Template (WIP)
    ├── frontend/                     # Next.js app
    └── backend/                      # BFF (optional)
```

---

## Quick Reference

### Key URLs

| Service | URL |
|---------|-----|
| Keycloak Admin | https://auth.atparui.com/admin |
| Gateway Admin | https://rmsgateway.atparui.com (or localhost:8082) |
| Jenkins | https://jenkins.atparui.com |
| Consul | https://consul.atparui.com |

### Default Credentials (Change in Production!)

| Service | User | Password |
|---------|------|----------|
| Keycloak Admin | `admin` | (from .env) |
| Gateway | `gwadmin` | `gwadmin` |
| Gateway | `platformadmin` | `PlatformAdmin123!` |
| Infra (Jenkins/Consul) | `infra-admin` | `InfraAdmin@2024!` |
| Infra (Jenkins/Consul) | `devops-lead` | `DevOps@2024!` |

---

## Next Steps

1. **Complete Web App Template** - Finalize `rms-web-template` with modular architecture
2. **Create Mobile Template** - React Native or Flutter with same architecture
3. **Automate Tenant Onboarding** - Script to fork repo, configure, and deploy
4. **Add Subscription Entity** - Track billing and feature access
5. **Build Self-Service Portal** - Demo → Register → Deploy flow
6. **Deploy Second Platform** - Neo Banking to validate multi-platform design

---

## Related Documentation

- [INFRASTRUCTURE_REALM_SETUP.md](INFRASTRUCTURE_REALM_SETUP.md) - DevOps authentication
- [TENANT_APP_ARCHITECTURE.md](TENANT_APP_ARCHITECTURE.md) - Modular app design
- [JENKINS_KEYCLOAK_INTEGRATION.md](JENKINS_KEYCLOAK_INTEGRATION.md) - CI/CD auth
- [CONSUL_OAUTH2_SETUP.md](CONSUL_OAUTH2_SETUP.md) - Service discovery auth
