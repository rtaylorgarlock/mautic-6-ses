#!/bin/sh
# Exit immediately if a command exits with a non-zero status.
set -e

# Define the Mautic directory.
MAUTIC_DIR=/var/www/html/docroot

echo "Running Mautic entrypoint script..."

# Create missing $MAUTIC_DIR/config/local.php if it does not exist
echo "Checking for local.php config file..."
if [ ! -f "$MAUTIC_DIR/config/local.php" ]; then
    echo "Creating missing local.php config file..."
    touch "$MAUTIC_DIR/config/local.php"
    echo "<?php\n// Local configuration stub\nreturn [];" > "$MAUTIC_DIR/config/local.php"
fi

# Create var directory if it doesn't exist and set permissions
echo "Setting up var directory and permissions..."
mkdir -p "$MAUTIC_DIR/var/cache"
mkdir -p "$MAUTIC_DIR/var/logs" 
mkdir -p "$MAUTIC_DIR/var/tmp"

# Set permissions on directories that need to be writable
chown -R www-data:www-data "$MAUTIC_DIR/var"
chown -R www-data:www-data "$MAUTIC_DIR/media"
chown -R www-data:www-data "$MAUTIC_DIR/config"

# Wait for database to be ready
echo "Waiting for database connection..."
until php /var/www/html/bin/console doctrine:query:sql "SELECT 1" > /dev/null 2>&1; do
    echo "Database not ready yet, waiting..."
    sleep 5
done

# Run database migrations
echo "Applying database migrations..."
php /var/www/html/bin/console doctrine:migrations:migrate --no-interaction

# Clear cache
echo "Clearing Mautic cache..."
php /var/www/html/bin/console cache:clear

echo "Entrypoint script finished. Starting application..."

# Finally exec the incoming CMD
exec "$@"
