# Debugging Theme Not Loading

## Issue
Theme `rms-auth-theme-plugin` is not appearing in Keycloak Admin Console dropdown, and templates are not found.

## Steps to Debug

### 1. Verify JAR is in Container's Providers Folder
```bash
docker compose -f docker-compose.yml exec keycloak ls -la /opt/keycloak/providers/ | grep theme
```

### 2. Check if Keycloak Scanned Providers on Startup
```bash
docker compose -f docker-compose.yml logs keycloak | grep -i "provider\|scan\|jar" | head -50
```

### 3. Check for Provider Loading Errors
```bash
docker compose -f docker-compose.yml logs keycloak | grep -i "error.*provider\|failed.*provider\|exception.*provider"
```

### 4. Verify JAR File Permissions
```bash
docker compose -f docker-compose.yml exec keycloak ls -la /opt/keycloak/providers/keycloak-theme-for-kc-26.2-and-above.jar
```

### 5. Check if JAR is Readable
```bash
docker compose -f docker-compose.yml exec keycloak file /opt/keycloak/providers/keycloak-theme-for-kc-26.2-and-above.jar
```

### 6. Verify JAR Contents Inside Container
```bash
docker compose -f docker-compose.yml exec keycloak jar -tf /opt/keycloak/providers/keycloak-theme-for-kc-26.2-and-above.jar | grep keycloak-themes.json
```

### 7. Check Theme Registration
```bash
docker compose -f docker-compose.yml exec keycloak jar -xf /opt/keycloak/providers/keycloak-theme-for-kc-26.2-and-above.jar META-INF/keycloak-themes.json && cat META-INF/keycloak-themes.json
```

### 8. Check Startup Logs for Theme Loading
```bash
docker compose -f docker-compose.yml logs keycloak | grep -E "(Starting|theme|Theme|provider)" | head -100
```

