# Mautic 6 with AWS SES Plugin

This project is a Mautic 6 installation managed via Composer, with the AWS SES plugin included for email delivery via Amazon Simple Email Service. Packaged and tested by a salty marketer, tired of 'one-click' deployments which guarantee you'll regret the one-click path for the entire life of the application. 
Consider this non-functional and unusable until told otherwise.

## Docker Deployment

### Quick Start

1. **Clone and setup environment**:
   ```bash
   git clone <your-repo-url>
   cd <project-directory>
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Build and run**:
   ```bash
   docker compose up -d
   ```

3. **Access Mautic**:
   - Open http://localhost:8080 in your browser
   - Complete the Mautic installation wizard
   - Configure AWS SES in the Email Settings

### CLI Commands

Run Mautic console commands inside the container:
```bash
docker compose exec mautic php bin/console <command>
```

Examples:
```bash
# Clear cache
docker compose exec mautic php bin/console cache:clear

# Run migrations
docker compose exec mautic php bin/console doctrine:migrations:migrate

# Create a user
docker compose exec mautic php bin/console mautic:user:create
```

### Updating AWS SES Plugin

To update the AWS SES plugin:
1. Update the version in `composer.json`
2. Run: `composer update kuzmany/mautic-amazon-ses`
3. Rebuild the Docker image: `docker compose build --no-cache mautic`
