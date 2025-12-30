#!/usr/bin/env sh
# Quick script to set up .env file from env.example

if [ -f ".env" ]; then
  echo "WARNING: .env file already exists!"
  printf "Do you want to overwrite it? (y/N): "
  read REPLY
  case "$REPLY" in
    [Yy]*) ;;
    *) 
      echo "Aborted. .env file not changed."
      exit 0
      ;;
  esac
fi

cp env.example .env
echo "✅ Created .env file from env.example"
echo ""
echo "📝 Next steps:"
echo "   1. Review and update .env file with your specific values"
echo "   2. Update MSG91_AUTH_KEY and MSG91_TEMPLATE_ID if using MSG91"
echo "   3. Update DOCKER_PASSWORD with your Docker Hub password"
echo "   4. For production, set ENVIRONMENT=prod and update URLs"
echo ""
echo "Then run: ./fresh-start.sh"

