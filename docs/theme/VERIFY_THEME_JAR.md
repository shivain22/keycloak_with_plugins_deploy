# Verify Theme JAR Contents in Container

Run these commands to verify the theme is properly registered:

## 1. Check JAR size and verify it matches
```bash
docker compose -f docker-compose.yml exec keycloak ls -lh /opt/keycloak/providers/keycloak-theme-for-kc-26.2-and-above.jar
```

## 2. Extract and verify keycloak-themes.json
```bash
docker compose -f docker-compose.yml exec keycloak sh -c "cd /tmp && jar -xf /opt/keycloak/providers/keycloak-theme-for-kc-26.2-and-above.jar META-INF/keycloak-themes.json && cat META-INF/keycloak-themes.json"
```

## 3. Check if login.ftl exists
```bash
docker compose -f docker-compose.yml exec keycloak jar -tf /opt/keycloak/providers/keycloak-theme-for-kc-26.2-and-above.jar | grep "login.ftl"
```

## 4. List all theme files
```bash
docker compose -f docker-compose.yml exec keycloak jar -tf /opt/keycloak/providers/keycloak-theme-for-kc-26.2-and-above.jar | grep "theme/rms-auth-theme-plugin"
```

## 5. Check theme directory structure
```bash
docker compose -f docker-compose.yml exec keycloak jar -tf /opt/keycloak/providers/keycloak-theme-for-kc-26.2-and-above.jar | head -50
```

