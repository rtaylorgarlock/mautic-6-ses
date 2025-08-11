#!/bin/sh
# Exit immediately if a command exits with a non-zero status.
set -e

# Define application (project) and web root directories.
APP_DIR=/var/www/html
WEB_DIR="$APP_DIR/docroot"

echo "Running Mautic entrypoint script..."

# Create missing $WEB_DIR/config/local.php if it does not exist
echo "Checking for local.php config file..."
if [ ! -f "$WEB_DIR/config/local.php" ]; then
    echo "Creating missing local.php config file..."
    touch "$WEB_DIR/config/local.php"
    echo "<?php\n// Local configuration stub\nreturn [];" > "$WEB_DIR/config/local.php"
fi

# Create var directory if it doesn't exist and set permissions
echo "Setting up var directory and permissions..."
mkdir -p "$WEB_DIR/var/cache"
mkdir -p "$WEB_DIR/var/logs" 
mkdir -p "$WEB_DIR/var/tmp"

# Set permissions on directories that need to be writable
chown -R www-data:www-data "$WEB_DIR/var"
chown -R www-data:www-data "$WEB_DIR/media"
chown -R www-data:www-data "$WEB_DIR/config"

# Wait for database to be ready (skippable on first-run)
if [ "${INITIAL_SKIP_DB_WAIT}" = "true" ] || [ "${INITIAL_SKIP_DB_WAIT}" = "1" ]; then
    echo "INITIAL_SKIP_DB_WAIT is set; skipping DB readiness wait for first run."
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

echo "Entrypoint script finished. Starting application..."

# Finally exec the incoming CMD
exec "$@"
