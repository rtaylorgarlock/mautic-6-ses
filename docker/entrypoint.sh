#!/bin/sh
# Exit immediately if a command exits with a non-zero status.
set -e

# Define application (project) and web root directories.
APP_DIR=/var/www/html
WEB_DIR="$APP_DIR/docroot"

echo "Running Mautic entrypoint script..."

# Detect installation by presence of real local.php at project config
echo "Checking for local.php config file..."
if [ -f "$APP_DIR/config/local.php" ]; then
    if grep -q "Local configuration stub" "$APP_DIR/config/local.php" 2>/dev/null; then
        INSTALLED=0
        echo "local.php looks like a stub; treating as NOT installed."
    else
        INSTALLED=1
        echo "local.php found; assuming Mautic is installed."
    fi
else
    INSTALLED=0
    echo "local.php not found; Mautic not installed yet. Skipping DB ops; proceed with web installer."
fi

# Create var directory if it doesn't exist and set permissions
echo "Setting up var directory and permissions..."
mkdir -p "$APP_DIR/config"
mkdir -p "$WEB_DIR/var/cache"
mkdir -p "$WEB_DIR/var/logs" 
mkdir -p "$WEB_DIR/var/tmp"

# Set permissions on directories that need to be writable
chown -R www-data:www-data "$APP_DIR/config"
chown -R www-data:www-data "$WEB_DIR/var"
chown -R www-data:www-data "$WEB_DIR/media"

if [ "$INSTALLED" -eq 1 ]; then
    # Wait for database to be ready (skippable via flag)
    if [ "${INITIAL_SKIP_DB_WAIT}" = "true" ] || [ "${INITIAL_SKIP_DB_WAIT}" = "1" ]; then
        echo "INITIAL_SKIP_DB_WAIT is set; skipping DB readiness wait for this run."
    else
        echo "Waiting for database connection..."
        until php "$APP_DIR/bin/console" doctrine:query:sql "SELECT 1" > /dev/null 2>&1; do
            echo "Database not ready yet, waiting..."
            sleep 5
        done
    fi

    # Run database migrations
    echo "Applying database migrations..."
    php "$APP_DIR/bin/console" doctrine:migrations:migrate --no-interaction

    # Clear cache
    echo "Clearing Mautic cache..."
    php "$APP_DIR/bin/console" cache:clear

    # Generate assets (respect PHP_INI_MEMORY_LIMIT if provided)
    echo "Generating Mautic assets..."
    php -d memory_limit=${PHP_INI_MEMORY_LIMIT:-512M} "$APP_DIR/bin/console" mautic:assets:generate
else
    echo "Mautic not installed; skip migrations and cache tasks."
fi

echo "Entrypoint script finished. Starting application..."

# Hand off to the base image entrypoint for proper PHP/Apache initialization
if [ -x "/usr/local/bin/docker-php-entrypoint" ]; then
  exec /usr/local/bin/docker-php-entrypoint "$@"
else
  exec "$@"
fi
