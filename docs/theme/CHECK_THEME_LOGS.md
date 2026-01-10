# Commands to Check if Theme is Loaded in Keycloak

## Using Docker Compose Logs (Recommended)

### Check for theme loading messages:
```bash
docker compose -f docker-compose.yml logs keycloak | grep -i "theme.*rms-auth-theme-plugin"
```

### Check for theme loading in general:
```bash
docker compose -f docker-compose.yml logs keycloak | grep -i "theme.*loaded"
```

### Check for any theme-related errors:
```bash
docker compose -f docker-compose.yml logs keycloak | grep -i "theme" | grep -i "error"
```

### Follow logs in real-time and filter for theme:
```bash
docker compose -f docker-compose.yml logs -f keycloak | grep -i "theme"
```

## More Specific Grep Patterns

### Check if theme is registered:
```bash
docker compose -f docker-compose.yml logs keycloak | grep -i "rms-auth-theme-plugin"
```

### Check for theme provider loading:
```bash
docker compose -f docker-compose.yml logs keycloak | grep -i "theme.*provider"
```

### Check for JAR file loading:
```bash
docker compose -f docker-compose.yml logs keycloak | grep -i "keycloak-theme-for-kc-26.2"
```

## Check Log Files Directly (if mounted as volume)

If logs are written to a mounted volume, you can check directly:
```bash
# Find log file location (usually in /opt/keycloak/data/log/)
docker compose -f docker-compose.yml exec keycloak find /opt/keycloak -name "*.log" -type f

# Then grep the log file
docker compose -f docker-compose.yml exec keycloak grep -i "rms-auth-theme-plugin" /opt/keycloak/data/log/*.log
```

## Comprehensive Check (All at once)

```bash
docker compose -f docker-compose.yml logs keycloak | grep -E "(theme|rms-auth-theme-plugin|keycloak-theme-for-kc)" -i
```

## Check for Template Loading Errors

```bash
docker compose -f docker-compose.yml logs keycloak | grep -E "(login\.ftl|Template not found|FreeMarkerException)" -i
```

