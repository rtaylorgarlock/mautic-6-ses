# Mautic 6 on Coolify

This project follows the Mautic "recommended-project" layout (web root is `docroot/`).

## Overview
- Image builds with multi-stage `Dockerfile`.
- Composer dependencies are installed with `--no-scripts` in the builder stage (no Node required at build time).
- Runtime setup happens in `docker/entrypoint.sh`:
  - Ensures writable dirs
  - Waits for DB
  - Runs Doctrine migrations
  - Clears cache
  - Generates assets via `mautic:assets:generate`
- Cron is managed by Coolify Scheduled Jobs (not inside the container).

## Environment variables (Coolify App UI)
Set at minimum:
- `MAUTIC_DB_HOST` – database host/service name
- `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` – DB credentials for Mautic
- `MAUTIC_SITE_URL` – public URL (e.g., `https://mautic.example.com`)
- `MAUTIC_RUN_CRON_JOBS=false` – cron handled by Coolify jobs

Recommended:
- `MAUTIC_TRUSTED_PROXIES=["0.0.0.0/0"]`
- `PHP_INI_MEMORY_LIMIT=512M`
- `PHP_INI_MAX_EXECUTION_TIME=300`

## Persistent volumes (Coolify App UI)
Map these paths to persistent volumes:
- `/var/www/html/docroot/config`
- `/var/www/html/docroot/media`
- `/var/www/html/docroot/var/logs`
- `/var/www/html/docroot/var/cache`

## Scheduled Jobs (Coolify)
Create scheduled jobs that exec inside the container. Suggested intervals and commands:

- Segments update (every 5 min):
  ```bash
  php -d memory_limit=${PHP_INI_MEMORY_LIMIT:-512M} /var/www/html/docroot/bin/console mautic:segments:update --batch-limit=500
  ```
- Campaigns update (every 5–10 min):
  ```bash
  php /var/www/html/docroot/bin/console mautic:campaigns:update --batch-limit=500
  ```
- Campaigns trigger (every 5–10 min, offset by a couple of minutes from update):
  ```bash
  php /var/www/html/docroot/bin/console mautic:campaigns:trigger --batch-limit=500
  ```
- Messages send (every 5–15 min):
  ```bash
  php -d memory_limit=${PHP_INI_MEMORY_LIMIT:-512M} /var/www/html/docroot/bin/console mautic:messages:send --batch-limit=500
  ```

Optional jobs:
- Email fetch (IMAP): `php /var/www/html/docroot/bin/console mautic:email:fetch`
- Imports: `php /var/www/html/docroot/bin/console mautic:import`
- Broadcasts: `php /var/www/html/docroot/bin/console mautic:broadcasts:send`

Tips:
- Stagger job schedules slightly to reduce contention.
- Increase `--batch-limit` and memory if needed.

## Deploy steps
1) Create a new App from your Git repo.
2) Configure the environment variables above.
3) Add the four volumes with the listed paths.
4) Build & Deploy.
5) Check logs on first deploy; expect:
   - DB wait → migrations → cache clear → assets generation → Apache start.

## Troubleshooting
- First-run DB wait loop: If Mautic is not configured yet and the console cannot connect to DB, add a temporary env (e.g. `INITIAL_SKIP_DB_WAIT=true`) and update `docker/entrypoint.sh` to bypass the wait once. Remove after initial setup.
- Permissions: Ensure volumes are attached; entrypoint sets ownership recursively on `var/`, `media/`, `config/`.
- Memory: If assets generation or segments/messages need more memory, raise `PHP_INI_MEMORY_LIMIT`.

## Notes on Node
- The final image does not include Node. Assets are generated via PHP (`mautic:assets:generate`).
- If you later need JS build steps (custom themes/plugins), add a Node builder stage and copy built assets into the final image to keep runtime lean.
