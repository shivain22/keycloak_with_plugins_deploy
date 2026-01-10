# Cursor AI Rules Configuration

## Overview
This project uses a `.cursorrules` file to configure Cursor AI behavior. The rules ensure consistent documentation organization and coding practices.

## Rule: Documentation Location

**All `.md` files must be created in the `docs/` folder**, organized by subject matter.

### Exception
- `README.md` should remain in the project root (standard practice)

### Organization Structure
When creating new documentation, place it in the appropriate subfolder:

- `docs/realms/` - Realm configuration and setup
- `docs/infrastructure/` - Infrastructure tools (Jenkins, Consul, etc.)
- `docs/database/` - Database configuration and multi-tenant setup
- `docs/theme/` - Theme and plugin documentation
- `docs/deployment/` - Deployment and setup guides
- `docs/architecture/` - Architecture and design documentation
- `docs/troubleshooting/` - Troubleshooting guides
- `docs/` - General documentation (if no specific category fits)

## How Cursor AI Uses .cursorrules

The `.cursorrules` file in the project root is automatically read by Cursor AI. When you ask Cursor AI to create documentation or make changes, it will:

1. ✅ Always create `.md` files in `docs/` folder (except README.md)
2. ✅ Organize files by subject matter in appropriate subfolders
3. ✅ Follow naming conventions (UPPERCASE_WITH_UNDERSCORES.md)
4. ✅ Follow project-specific coding guidelines

## Viewing Current Rules

To see all rules, check the `.cursorrules` file in the project root:

```bash
cat .cursorrules
```

## Updating Rules

To add or modify rules, edit the `.cursorrules` file. Cursor AI will automatically use the updated rules in future conversations.

## Example

When you ask: "Create documentation for the new feature X"

Cursor AI will:
- ✅ Create `docs/feature/X_FEATURE.md` (or appropriate subfolder)
- ❌ NOT create `X_FEATURE.md` in the root directory

## Date
Rules configured: 2024-12-19
