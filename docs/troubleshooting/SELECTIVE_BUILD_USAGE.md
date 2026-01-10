# Selective Build Usage with start.sh

## Quick Start

You can now use `start.sh` with selective build flags:

### Build Only Theme
```bash
./start.sh --theme-only
```

### Build Only Phone Provider
```bash
./start.sh --phone-provider-only
```

### Build Theme and Start Services
```bash
./start.sh --build --theme-only
```

### Less Verbose Build
```bash
./start.sh --theme-only --quiet-build
```

## All Available Flags

### Build Selection
- `--theme-only` - Build only theme (preserves existing phone provider JARs)
- `--phone-provider-only` - Build only phone provider (preserves existing theme JAR)
- `--quiet-build` - Less verbose build output

### Build Control
- `--build` - Force build all components
- `--no-build` - Skip build, just start services
- `--pull` - Pull images from Docker Hub instead of building

### Service Control
- `--runtime` - Use runtime compose (no builders)
- `--clean` - Remove volumes (deletes database data)
- `--logs` - Tail logs after start
- `--setup-env` - Run setup-env.sh interactively

## Examples

### Debug Theme Build
```bash
# Build only theme and start services
./start.sh --theme-only

# Build theme with quiet output
./start.sh --theme-only --quiet-build

# Force rebuild theme only
./start.sh --build --theme-only
```

### Quick Phone Provider Update
```bash
# Build only phone provider
./start.sh --phone-provider-only
```

### Full Help
```bash
./start.sh --help
```

## How It Works

1. Flags are passed to `start.sh`
2. `start.sh` passes them to the `artifacts` container
3. The build script builds only the selected components
4. Existing JARs for non-selected components are preserved
5. Services start normally after build

## Benefits

- **Faster iteration** - Rebuild only what changed
- **Preserves work** - Don't lose existing JARs
- **Better debugging** - Focus on one component at a time
- **Same workflow** - Use start.sh as always, just add flags

