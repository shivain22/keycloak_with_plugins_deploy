# Tenant Application Architecture

## Overview

This document outlines the modular architecture for tenant web and mobile applications. Each tenant gets their own Git repository (forked from template) enabling:

- **Standard Subscription**: Configuration-only changes (branding, colors, logos)
- **Premium Subscription**: Full repo access for programmatic customizations

---

## Repository Structure

### Organization Layout

```
GitHub Organization: atpar-saas
│
├── TEMPLATE REPOS (Internal - Maintained by ATPAR)
│   ├── rms-web-template/           # Base Next.js webapp
│   ├── rms-mobile-template/        # Base React Native / Flutter app
│   ├── neo-web-template/           # Neo Banking webapp (future)
│   └── neo-mobile-template/        # Neo Banking mobile (future)
│
├── TENANT REPOS (Forked per tenant)
│   ├── rms-web-taj/                # Taj Restaurant webapp
│   ├── rms-mobile-taj/             # Taj Restaurant mobile
│   ├── rms-web-marriott/           # Marriott webapp
│   └── rms-mobile-marriott/        # Marriott mobile
│
└── SHARED LIBS (NPM packages)
    ├── @atpar/ui-components/       # Shared UI components
    ├── @atpar/auth-client/         # Keycloak auth wrapper
    └── @atpar/api-client/          # API client with tenant routing
```

---

## Modular Architecture

### Web App Template Structure

```
rms-web-template/
├── src/
│   ├── core/                       # 🔒 CORE - Rarely modified
│   │   ├── api/                    # API client, interceptors
│   │   ├── auth/                   # Keycloak integration
│   │   ├── hooks/                  # Shared React hooks
│   │   ├── store/                  # State management
│   │   └── utils/                  # Utility functions
│   │
│   ├── features/                   # 🔒 FEATURES - Business logic
│   │   ├── orders/                 # Order management
│   │   ├── menu/                   # Menu management
│   │   ├── billing/                # Billing & payments
│   │   ├── customers/              # Customer management
│   │   └── reports/                # Analytics & reports
│   │
│   ├── ui/                         # 🎨 UI - Easily customizable
│   │   ├── components/             # Reusable UI components
│   │   ├── layouts/                # Page layouts
│   │   └── primitives/             # Base UI primitives (buttons, inputs)
│   │
│   └── tenant/                     # ✏️ TENANT CONFIG - Per-tenant
│       ├── config.ts               # Tenant configuration
│       ├── theme.ts                # Theme/branding
│       ├── assets/                 # Logos, images
│       ├── routes.ts               # Route customizations
│       └── features.ts             # Feature flags
│
├── public/
│   └── tenant/                     # Tenant static assets
│       ├── logo.svg
│       ├── favicon.ico
│       └── og-image.png
│
├── tailwind.config.js              # Extends tenant theme
├── next.config.js                  # Build configuration
└── package.json
```

### Mobile App Template Structure

```
rms-mobile-template/
├── src/
│   ├── core/                       # 🔒 CORE - Rarely modified
│   │   ├── api/
│   │   ├── auth/
│   │   ├── navigation/
│   │   └── store/
│   │
│   ├── features/                   # 🔒 FEATURES - Business logic
│   │   ├── orders/
│   │   ├── menu/
│   │   ├── tables/
│   │   └── notifications/
│   │
│   ├── ui/                         # 🎨 UI - Customizable
│   │   ├── components/
│   │   ├── screens/
│   │   └── theme/
│   │
│   └── tenant/                     # ✏️ TENANT CONFIG
│       ├── config.ts
│       ├── theme.ts
│       └── assets/
│
├── android/                        # Android native config
│   └── app/
│       └── src/main/res/           # App icons, splash
│
├── ios/                            # iOS native config
│   └── Images.xcassets/            # App icons, splash
│
└── app.json                        # App metadata
```

---

## Configuration Files

### Tenant Config (`src/tenant/config.ts`)

```typescript
// src/tenant/config.ts
export const tenantConfig = {
  // Identity
  tenantId: 'taj',
  tenantKey: 'taj-restaurant',
  name: 'Taj Restaurant',
  
  // API Configuration
  api: {
    gatewayUrl: 'https://api.atparui.com',
    serviceUrl: 'https://rms-api.atparui.com',
    timeout: 30000,
  },
  
  // Authentication
  auth: {
    keycloakUrl: 'https://auth.atparui.com',
    realm: 'taj-realm',
    clientId: 'taj-web',
  },
  
  // Branding
  branding: {
    companyName: 'Taj Restaurant Group',
    tagline: 'Fine Dining Experience',
    supportEmail: 'support@tajrestaurant.com',
    supportPhone: '+91-1234567890',
  },
  
  // URLs
  urls: {
    website: 'https://tajrestaurant.com',
    privacyPolicy: 'https://tajrestaurant.com/privacy',
    termsOfService: 'https://tajrestaurant.com/terms',
  },
  
  // Localization
  localization: {
    defaultLocale: 'en',
    supportedLocales: ['en', 'hi'],
    currency: 'INR',
    currencySymbol: '₹',
    dateFormat: 'DD/MM/YYYY',
    timeFormat: '12h',
  },
};
```

### Theme Configuration (`src/tenant/theme.ts`)

```typescript
// src/tenant/theme.ts
export const tenantTheme = {
  // Colors
  colors: {
    primary: {
      50: '#fef2f2',
      100: '#fee2e2',
      500: '#ef4444',   // Main brand color
      600: '#dc2626',
      700: '#b91c1c',
    },
    secondary: {
      500: '#f59e0b',
      600: '#d97706',
    },
    accent: '#10b981',
    background: '#ffffff',
    foreground: '#171717',
    muted: '#f5f5f5',
    border: '#e5e5e5',
  },
  
  // Typography
  fonts: {
    heading: 'Playfair Display, serif',
    body: 'Inter, sans-serif',
    mono: 'JetBrains Mono, monospace',
  },
  
  // Border Radius
  borderRadius: {
    sm: '0.375rem',
    md: '0.5rem',
    lg: '0.75rem',
    xl: '1rem',
    full: '9999px',
  },
  
  // Shadows
  shadows: {
    sm: '0 1px 2px rgba(0, 0, 0, 0.05)',
    md: '0 4px 6px rgba(0, 0, 0, 0.1)',
    lg: '0 10px 15px rgba(0, 0, 0, 0.1)',
  },
  
  // Component Variants
  components: {
    button: {
      defaultVariant: 'solid',
      borderRadius: 'md',
    },
    card: {
      borderRadius: 'lg',
      shadow: 'md',
    },
    input: {
      borderRadius: 'md',
    },
  },
};

// CSS Variables export for Tailwind
export const cssVariables = {
  '--color-primary': tenantTheme.colors.primary[500],
  '--color-primary-dark': tenantTheme.colors.primary[700],
  '--color-secondary': tenantTheme.colors.secondary[500],
  '--color-accent': tenantTheme.colors.accent,
  '--font-heading': tenantTheme.fonts.heading,
  '--font-body': tenantTheme.fonts.body,
  '--radius-sm': tenantTheme.borderRadius.sm,
  '--radius-md': tenantTheme.borderRadius.md,
  '--radius-lg': tenantTheme.borderRadius.lg,
};
```

### Feature Flags (`src/tenant/features.ts`)

```typescript
// src/tenant/features.ts
export const featureFlags = {
  // Subscription tier features
  subscription: {
    tier: 'premium',  // 'basic' | 'standard' | 'premium' | 'enterprise'
    
    // Feature access by tier
    features: {
      // Basic (all tiers)
      orders: true,
      menu: true,
      billing: true,
      
      // Standard+
      tableManagement: true,
      customerLoyalty: true,
      
      // Premium+
      multiLocation: true,
      advancedReports: true,
      apiAccess: true,
      
      // Enterprise
      whiteLabel: true,
      customIntegrations: true,
      dedicatedSupport: true,
    },
  },
  
  // UI/UX Features
  ui: {
    showLogo: true,
    showPoweredBy: false,        // Hide "Powered by ATPAR" for premium
    darkMode: true,
    compactMode: false,
    animations: true,
  },
  
  // Integrations
  integrations: {
    razorpay: true,
    stripe: false,
    whatsapp: true,
    sms: true,
    email: true,
    pos: {
      enabled: true,
      provider: 'square',       // 'square' | 'clover' | 'custom'
    },
    delivery: {
      swiggy: true,
      zomato: true,
      ubereats: false,
    },
  },
  
  // Experimental / Beta
  beta: {
    aiRecommendations: false,
    voiceOrdering: false,
    arMenu: false,
  },
};
```

---

## API Client Architecture

### Base API Client (`src/core/api/client.ts`)

```typescript
// src/core/api/client.ts
import axios, { AxiosInstance } from 'axios';
import { tenantConfig } from '@/tenant/config';
import { getAccessToken } from '@/core/auth';

class ApiClient {
  private client: AxiosInstance;
  
  constructor() {
    this.client = axios.create({
      baseURL: tenantConfig.api.serviceUrl,
      timeout: tenantConfig.api.timeout,
      headers: {
        'Content-Type': 'application/json',
        'X-Tenant-ID': tenantConfig.tenantId,
      },
    });
    
    this.setupInterceptors();
  }
  
  private setupInterceptors() {
    // Request interceptor - Add auth token
    this.client.interceptors.request.use(async (config) => {
      const token = await getAccessToken();
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
      return config;
    });
    
    // Response interceptor - Handle errors
    this.client.interceptors.response.use(
      (response) => response,
      async (error) => {
        if (error.response?.status === 401) {
          // Handle token refresh or logout
          await this.handleUnauthorized();
        }
        return Promise.reject(error);
      }
    );
  }
  
  private async handleUnauthorized() {
    // Refresh token or redirect to login
  }
  
  // HTTP methods
  get = <T>(url: string, config = {}) => 
    this.client.get<T>(url, config);
  
  post = <T>(url: string, data = {}, config = {}) => 
    this.client.post<T>(url, data, config);
  
  put = <T>(url: string, data = {}, config = {}) => 
    this.client.put<T>(url, data, config);
  
  delete = <T>(url: string, config = {}) => 
    this.client.delete<T>(url, config);
}

export const api = new ApiClient();
```

### Feature-specific API (`src/features/orders/api.ts`)

```typescript
// src/features/orders/api.ts
import { api } from '@/core/api/client';
import { Order, CreateOrderDTO, OrderStatus } from './types';

export const ordersApi = {
  getAll: (params?: { status?: OrderStatus; date?: string }) =>
    api.get<Order[]>('/api/orders', { params }),
  
  getById: (id: string) =>
    api.get<Order>(`/api/orders/${id}`),
  
  create: (data: CreateOrderDTO) =>
    api.post<Order>('/api/orders', data),
  
  updateStatus: (id: string, status: OrderStatus) =>
    api.put<Order>(`/api/orders/${id}/status`, { status }),
  
  cancel: (id: string, reason: string) =>
    api.post<void>(`/api/orders/${id}/cancel`, { reason }),
};
```

---

## Authentication Module

### Keycloak Integration (`src/core/auth/keycloak.ts`)

```typescript
// src/core/auth/keycloak.ts
import Keycloak from 'keycloak-js';
import { tenantConfig } from '@/tenant/config';

let keycloakInstance: Keycloak | null = null;

export const initKeycloak = async (): Promise<boolean> => {
  keycloakInstance = new Keycloak({
    url: tenantConfig.auth.keycloakUrl,
    realm: tenantConfig.auth.realm,
    clientId: tenantConfig.auth.clientId,
  });
  
  try {
    const authenticated = await keycloakInstance.init({
      onLoad: 'check-sso',
      silentCheckSsoRedirectUri: 
        window.location.origin + '/silent-check-sso.html',
      pkceMethod: 'S256',
    });
    
    if (authenticated) {
      scheduleTokenRefresh();
    }
    
    return authenticated;
  } catch (error) {
    console.error('Keycloak init failed:', error);
    return false;
  }
};

export const login = () => keycloakInstance?.login();
export const logout = () => keycloakInstance?.logout();
export const getAccessToken = () => keycloakInstance?.token;
export const isAuthenticated = () => !!keycloakInstance?.authenticated;

export const getUserInfo = () => ({
  id: keycloakInstance?.subject,
  username: keycloakInstance?.tokenParsed?.preferred_username,
  email: keycloakInstance?.tokenParsed?.email,
  roles: keycloakInstance?.tokenParsed?.roles || [],
  tenantId: keycloakInstance?.tokenParsed?.tenant_id,
});

const scheduleTokenRefresh = () => {
  const tokenParsed = keycloakInstance?.tokenParsed;
  if (!tokenParsed?.exp) return;
  
  const expiresIn = tokenParsed.exp * 1000 - Date.now();
  const refreshTime = expiresIn - 60000; // Refresh 1 min before expiry
  
  setTimeout(async () => {
    try {
      await keycloakInstance?.updateToken(70);
      scheduleTokenRefresh();
    } catch {
      logout();
    }
  }, refreshTime);
};
```

---

## Theming System

### Tailwind Integration (`tailwind.config.js`)

```javascript
// tailwind.config.js
const { tenantTheme } = require('./src/tenant/theme');

module.exports = {
  content: ['./src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: tenantTheme.colors.primary,
        secondary: tenantTheme.colors.secondary,
        accent: tenantTheme.colors.accent,
        background: tenantTheme.colors.background,
        foreground: tenantTheme.colors.foreground,
        muted: tenantTheme.colors.muted,
        border: tenantTheme.colors.border,
      },
      fontFamily: {
        heading: [tenantTheme.fonts.heading],
        body: [tenantTheme.fonts.body],
        mono: [tenantTheme.fonts.mono],
      },
      borderRadius: tenantTheme.borderRadius,
      boxShadow: tenantTheme.shadows,
    },
  },
  plugins: [require('tailwindcss-animate')],
};
```

### Theme Provider (`src/ui/components/ThemeProvider.tsx`)

```tsx
// src/ui/components/ThemeProvider.tsx
'use client';

import { createContext, useContext, useEffect, useState } from 'react';
import { tenantTheme, cssVariables } from '@/tenant/theme';

type Theme = 'light' | 'dark' | 'system';

interface ThemeContextType {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  colors: typeof tenantTheme.colors;
}

const ThemeContext = createContext<ThemeContextType | null>(null);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<Theme>('system');
  
  useEffect(() => {
    // Apply CSS variables to root
    const root = document.documentElement;
    Object.entries(cssVariables).forEach(([key, value]) => {
      root.style.setProperty(key, value);
    });
  }, []);
  
  useEffect(() => {
    const root = document.documentElement;
    root.classList.remove('light', 'dark');
    
    if (theme === 'system') {
      const systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches
        ? 'dark'
        : 'light';
      root.classList.add(systemTheme);
    } else {
      root.classList.add(theme);
    }
  }, [theme]);
  
  return (
    <ThemeContext.Provider value={{ theme, setTheme, colors: tenantTheme.colors }}>
      {children}
    </ThemeContext.Provider>
  );
}

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) throw new Error('useTheme must be used within ThemeProvider');
  return context;
};
```

---

## Tenant Onboarding Workflow

### 1. Create Tenant in Gateway

```
Gateway Admin UI → Create Tenant
  ↓
  - Creates database schema
  - Creates Keycloak realm
  - Creates OAuth clients (web, mobile, service)
  - Returns tenant configuration
```

### 2. Fork Repository

```bash
# Automated script or manual
gh repo fork atpar-saas/rms-web-template \
  --clone \
  --org atpar-saas \
  --name rms-web-{tenant-key}
```

### 3. Configure Tenant

```bash
# Clone tenant repo
git clone git@github.com:atpar-saas/rms-web-{tenant-key}.git
cd rms-web-{tenant-key}

# Update tenant configuration
# Edit: src/tenant/config.ts
# Edit: src/tenant/theme.ts
# Edit: src/tenant/features.ts
# Add: src/tenant/assets/logo.svg

# Commit and push
git add .
git commit -m "Configure tenant: {tenant-name}"
git push origin main
```

### 4. Deploy

```bash
# CI/CD triggers on push to main
# Deploys to: {tenant-key}.rms.atparui.com
```

---

## CI/CD Pipeline

### GitHub Actions Workflow (`.github/workflows/deploy.yml`)

```yaml
name: Deploy Tenant App

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  TENANT_KEY: ${{ github.event.repository.name }}

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Extract tenant key from repo name
        run: |
          # rms-web-taj -> taj
          TENANT=$(echo ${{ github.event.repository.name }} | sed 's/rms-web-//')
          echo "TENANT_KEY=$TENANT" >> $GITHUB_ENV
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build
        run: npm run build
        env:
          NEXT_PUBLIC_TENANT_KEY: ${{ env.TENANT_KEY }}
      
      - name: Build Docker image
        run: |
          docker build \
            --build-arg TENANT_KEY=${{ env.TENANT_KEY }} \
            -t rms-web-${{ env.TENANT_KEY }}:${{ github.sha }} \
            .
      
      - name: Push to Registry
        run: |
          docker tag rms-web-${{ env.TENANT_KEY }}:${{ github.sha }} \
            registry.atparui.com/rms-web-${{ env.TENANT_KEY }}:latest
          docker push registry.atparui.com/rms-web-${{ env.TENANT_KEY }}:latest
      
      - name: Deploy to Kubernetes
        run: |
          kubectl set image deployment/rms-web-${{ env.TENANT_KEY }} \
            app=registry.atparui.com/rms-web-${{ env.TENANT_KEY }}:${{ github.sha }}
```

---

## Subscription Tiers & Access

| Feature | Basic | Standard | Premium | Enterprise |
|---------|-------|----------|---------|------------|
| **Repo Access** | ❌ | ❌ | ✅ Read | ✅ Read/Write |
| **Branding** | Logo only | Full colors | Full + fonts | Full + custom CSS |
| **Feature Flags** | Limited | Standard | All | All + custom |
| **API Access** | ❌ | Read-only | Read/Write | Full + webhooks |
| **Support** | Community | Email | Priority | Dedicated |
| **Custom Domain** | ❌ | ❌ | ✅ | ✅ |
| **SLA** | None | 99.5% | 99.9% | 99.99% |

---

## Upstream Updates

### Pulling Updates from Template

```bash
# In tenant repo
git remote add upstream git@github.com:atpar-saas/rms-web-template.git

# Fetch latest changes
git fetch upstream

# Merge (careful with conflicts in tenant/ folder)
git merge upstream/main --no-edit

# Resolve conflicts (usually in src/tenant/ - keep tenant's version)
git checkout --ours src/tenant/
git add .
git commit -m "Merge upstream updates"
git push origin main
```

### Protected Files (never overwritten)

```
# .git-protected-paths
src/tenant/config.ts
src/tenant/theme.ts
src/tenant/features.ts
src/tenant/assets/
public/tenant/
```

---

## Summary

| Aspect | Implementation |
|--------|----------------|
| **Repo per Tenant** | Fork from template, full isolation |
| **Theming** | `src/tenant/theme.ts` + Tailwind CSS variables |
| **Configuration** | `src/tenant/config.ts` for all settings |
| **Feature Flags** | `src/tenant/features.ts` for subscription tiers |
| **API Access** | Core API client with tenant ID injection |
| **Authentication** | Keycloak per-tenant realm |
| **Updates** | Git upstream merge from template |
| **Deployment** | CI/CD per repo to tenant subdomain |

This architecture ensures:
- ✅ Clean separation of core vs tenant code
- ✅ Easy customization for premium clients
- ✅ Safe upstream updates
- ✅ Proper API isolation per tenant
- ✅ Scalable deployment model
