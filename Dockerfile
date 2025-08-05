FROM mautic/mautic:6-apache

WORKDIR /var/www/html

# Remove default Mautic files
RUN rm -rf ./*

# Copy the entire project
COPY . .

# Set proper ownership
RUN chown -R www-data:www-data /var/www/html

# Copy entrypoint script
COPY docker/entrypoint.sh /usr/local/bin/mautic-entrypoint.sh
RUN chmod +x /usr/local/bin/mautic-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/mautic-entrypoint.sh"]
CMD ["apache2-foreground"]
