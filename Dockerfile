# ==> Stage 1: Build dependencies with Composer
FROM composer:2 AS vendor
WORKDIR /app

# Copy composer files from your repository.
COPY composer.json composer.lock ./

# Install dependencies with production optimizations.
RUN composer install --no-interaction --no-dev --optimize-autoloader --no-scripts --ignore-platform-reqs


# ==> Stage 2: Build the final Mautic image
FROM mautic/mautic:6-apache
WORKDIR /var/www/html
RUN rm -rf vendor || true
COPY --from=vendor /app/vendor/ ./vendor/
COPY . .
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/docker-entrypoint.sh", "apache2-foreground"]
