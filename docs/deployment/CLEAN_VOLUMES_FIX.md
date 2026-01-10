# Fix for --clean Flag Not Removing Volumes

## Problem

The `start.sh --clean` command was using `docker compose down -v`, which sometimes doesn't remove volumes if:
- Volumes are still in use by stopped containers
- Volume names don't match exactly
- Docker Compose project name prefix affects volume names

## Solution

Updated `start.sh` to explicitly remove volumes by name:

1. **Stop containers first** - Ensures volumes aren't in use
2. **Remove volumes by actual names** - Tries both prefixed and non-prefixed names
3. **Fallback cleanup** - Still runs `docker compose down -v` as backup

## Volume Names

Docker Compose creates volumes with project name prefix:
- `{project_name}_postgres_data` (Keycloak database)
- `{project_name}_rms_postgres_data` (RMS databases)
- `{project_name}_m2_cache` (Maven cache)

The project name is usually the directory name (e.g., `keycloak_with_plugins_deploy`).

## Usage

```bash
# Remove all volumes and restart
./start.sh --clean

# This will:
# 1. Stop all containers
# 2. Remove postgres_data volume (Keycloak database)
# 3. Remove rms_postgres_data volume (RMS databases)
# 4. Remove m2_cache volume (Maven cache)
# 5. Start services with fresh databases
```

## Manual Volume Removal (if needed)

If `--clean` still doesn't work, you can manually remove volumes:

```bash
# List volumes
docker volume ls | grep postgres

# Remove specific volumes
docker volume rm keycloak_with_plugins_deploy_postgres_data
docker volume rm keycloak_with_plugins_deploy_rms_postgres_data
docker volume rm keycloak_with_plugins_deploy_m2_cache

# Or remove all unused volumes
docker volume prune -f
```

## Verification

After running `./start.sh --clean`, verify volumes are removed:

```bash
# Check if volumes exist
docker volume ls | grep -E "(postgres_data|rms_postgres_data|m2_cache)"

# Should show no volumes (or only volumes from other projects)
```

## What Gets Removed

- ✅ **postgres_data** - Keycloak database (all realms, users, clients, etc.)
- ✅ **rms_postgres_data** - RMS Gateway and Service databases
- ✅ **m2_cache** - Maven cache (can be rebuilt)

## What's Preserved

- ✅ **providers/** directory - JAR files (not a volume)
- ✅ **realm-import/** directory - Realm JSON files (not a volume)
- ✅ Docker images - Not removed by `--clean`

## After Clean Start

When you start Keycloak after `--clean`:
1. Keycloak will import realm JSON files from `realm-import/` directory
2. Fresh databases will be created
3. All realm configurations (theme, flows, etc.) will be imported

This is the best way to ensure your updated realm configurations are applied!

