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
# Point Apache to the recommended-project web root
ENV APACHE_DOCUMENT_ROOT=/var/www/html/docroot
RUN set -eux; \
    sed -ri -e "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/sites-available/*.conf || true; \
    sed -ri -e "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/apache2.conf || true
    
# Ensure both paths work for config: docroot/config -> ../config
RUN ln -sfn ../config docroot/config

# Enable rewrite and set a default ServerName to silence warnings
RUN a2enmod rewrite && echo "ServerName localhost" > /etc/apache2/conf-enabled/servername.conf
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
