# ==> Stage 1: Build dependencies with Composer
FROM composer:2 AS vendor
WORKDIR /app

# Install system libraries needed for the PHP extensions
# libzip-dev -> for zip; uw-imap-dev -> for imap
# libpng-dev & libjpeg-turbo-dev -> for gd (graphics)
RUN apk update && apk add --no-cache \
    libzip-dev \
    unzip \
    uw-imap-dev \
    libpng-dev \
    libjpeg-turbo-dev

# Configure, install, and enable all required PHP extensions in one go
RUN docker-php-ext-configure imap --with-imap --with-imap-ssl \
    && docker-php-ext-configure gd --with-jpeg --with-png \
    && docker-php-ext-install \
    zip \
    imap \
    bcmath \
    gd \
    sockets \
    pdo_mysql \
    mysqli

# NOTE: iconv is included in the base image, so no action is needed for it.

# Copy composer files from your repository.
COPY composer.json composer.lock ./

# Install dependencies with production optimizations.
RUN composer install --no-interaction --no-dev --optimize-autoloader --no-scripts


# ==> Stage 2: Build the final Mautic image
FROM mautic/mautic:6-apache
WORKDIR /var/www/html
RUN rm -rf .
COPY --from=vendor /app/vendor/ ./vendor/
COPY . .
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/docker-entrypoint.sh", "apache2-foreground"]
