# Setup Instructions

## First Time Setup

1. **Clone the repository** (if not already done)

2. **Set execute permissions** (Linux/Mac):
   ```bash
   chmod +x start.sh fresh-start.sh scripts/*.sh
   ```

3. **Run the startup script**:
   ```bash
   bash fresh-start.sh --rebuild
   ```
   
   Or if you prefer:
   ```bash
   ./fresh-start.sh --rebuild
   ```

## Important Notes

- The scripts will automatically create `.env` from `env.example` if it doesn't exist
- Use `bash` command to run scripts (not `sh`) for full compatibility
- All scripts use bash-specific features, so always use: `bash script.sh` or `./script.sh` (after chmod +x)

## Troubleshooting

### "Bad substitution" error
- **Solution**: Use `bash fresh-start.sh` instead of `sh fresh-start.sh`

### "Permission denied" error
- **Solution**: Run `chmod +x scripts/generate-realm-configs.sh`

### Scripts work after chmod but not after git clone
- **Solution**: The `.gitattributes` file should preserve permissions, but if not, run:
  ```bash
  chmod +x *.sh scripts/*.sh
  ```

