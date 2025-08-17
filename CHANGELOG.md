# Changelog and Development History

This project follows a pragmatic variant of "Keep a Changelog" to capture not only code changes but also key decisions and current state for GitOps-friendly deployments.

## [0.2.0] - 2025-08-13

### Added
- SNS bridge microservice at `services/sns-bridge/` (FastAPI) that validates AWS SNS and marks Contacts DNC via Mautic REST API.
- Apache reverse proxy config `docker/apache-sns-proxy.conf` to expose the bridge at `https://<mautic-domain>/sns/*`.
- `sns-bridge` service added to `docker-compose.yaml`; shares the app network.

### Changed
- Dockerfile: enable `proxy` and `proxy_http` modules; include SNS proxy conf; add `docroot/var -> ../var` symlink for runtime paths consistency.
- docker-compose.yaml: corrected volume mount points to `/var/www/html/var/{logs,cache}` (project root) to match where Symfony writes.
- Entrypoint: create/chown `APP_DIR/var/{cache,logs,tmp}` and re-chown after console tasks.
- Docs (`docs/coolify.md`): updated volume paths and console path to `/var/www/html/bin/console`. Added SNS bridge setup section (API Basic Auth, SNS topic subscription).

### Notes
- Set `MAUTIC_API_USERNAME` and `MAUTIC_API_PASSWORD` in Coolify when enabling the SNS bridge. In Mautic UI, enable API and Basic Auth.

---

## [0.1.0] - 2025-08-13

### Added
- Coolify deployment guide at `docs/coolify.md` (manual setup; focus on reproducibility and minimal friction).
- Strict env guards in `docker-compose.yaml` using `${VAR:?required}` for critical variables (DB, `APP_SECRET`, `MAUTIC_SITE_URL`).
- Healthcheck on the Percona DB service using `mysqladmin ping` with sensible timing.

### Changed
- Dockerfile (multi-stage):
  - Composer stage runs `composer install --no-dev --no-scripts --ignore-platform-reqs` to avoid build-time Node and platform issues.
  - Final image based on `mautic/mautic:6-apache` now:
    - Copies only `vendor/` from builder.
    - Sets Apache DocumentRoot to `docroot` (`/var/www/html/docroot`).
    - Enables `mod_rewrite` and sets a default `ServerName` to silence warnings.
    - Creates a symlink `docroot/config -> ../config` so both config paths work.
    - Fixes `CMD` to `apache2-foreground` (removes invalid `/docker-entrypoint.sh` reference).
- Entrypoint `docker/entrypoint.sh`:
  - Uses project root and web root constants: `APP_DIR=/var/www/html`, `WEB_DIR=$APP_DIR/docroot`.
  - Detects installation by checking `APP_DIR/config/local.php` and treating any stub as NOT installed.
  - Creates and chowns `APP_DIR/config` and required `var` paths under `docroot`.
  - Gates DB wait, migrations, cache clear, and asset generation until a real install exists.
  - Runs Symfony console from `APP_DIR/bin/console`.
  - Hands off to base `/usr/local/bin/docker-php-entrypoint` for reliable PHP/Apache startup.
- docker-compose.yaml:
  - Volume fix: mount config at `/var/www/html/config` (not `docroot/config`).
  - Persist media, logs, cache under `docroot/` to match recommended-project layout.
  - Keeps ports unexposed (Coolify handles routing); retains `depends_on` with DB health.

### Fixed
- Build failures due to missing Alpine packages (e.g., `uw-imap-dev`) by removing unnecessary system PHP extension builds from composer stage.
- Runtime crash from invalid `CMD ["/docker-entrypoint.sh", ...]` by executing `apache2-foreground` directly.
- Early migration failures by deferring all DB operations until a non-stub `local.php` exists.
- Apache serving from the wrong directory by explicitly setting DocumentRoot to `docroot` and enabling `mod_rewrite`.

### Documentation
- `docs/coolify.md` updated with:
  - Required environment variables and their meaning.
  - Volume mappings for config, media, logs, cache.
  - Scheduled Jobs commands (cron) to be run by Coolify (not in-container `cron`), e.g.:
    - `php -d memory_limit=512M /var/www/html/bin/console mautic:segments:update -q`
    - `php -d memory_limit=512M /var/www/html/bin/console mautic:campaigns:rebuild -q`
    - `php -d memory_limit=512M /var/www/html/bin/console mautic:campaigns:trigger -q`
    - `php -d memory_limit=512M /var/www/html/bin/console mautic:broadcasts:send -q`
    - `php -d memory_limit=512M /var/www/html/bin/console mautic:emails:send -q` (if queued)
    - `php -d memory_limit=512M /var/www/html/bin/console mautic:webhooks:process -q`

### Decisions & Rationale
- Prefer manual Coolify setup over Terraform/Coolify provider automation due to complexity and friction; focus on reliability and clarity for GitOps.
- Run Composer with `--no-scripts` to avoid Node at build time; let assets generate at runtime.
- Gate DB ops until install to avoid applying late migrations to an empty schema.
- Keep Cron out of the container; use Coolify Scheduled Jobs for consistency.
- Trust proxy and host configured post-install in `config/local.php` to avoid redirect loops in reverse-proxied environments.

### Current State
- Installer completed; app boots to Mautic dashboard.
- DB connectivity verified via `doctrine:query:sql` from inside the container.
- Apache configured for `docroot`; rewrite enabled; default `ServerName` set.
- Config stored at `/var/www/html/config/local.php` with symlink at `docroot/config` for Mautic compatibility.
- Coolify Scheduled Jobs to be added (if not already) using console commands listed above.
- SES SMTP can be configured in Mautic UI (Settings → Configuration → Email Settings → SMTP TLS 587 using SES SMTP creds).
- Preference: use AWS SNS for bounces/complaints (no IMAP needed). A small SNS bridge service will be added to compose in a future version.

### Known Issues / Next Steps
- Remove Terraform/Coolify automation files from repo (cleanup) and document fully manual Coolify steps.
- Add optional SNS bridge service for SES bounces/complaints and document SES topic/subscription.
- Confirm `config/local.php` contains `site_url`, `trusted_proxies`, and `trusted_hosts` (e.g., `https://m.dreliane.com`, `["0.0.0.0/0"]`, `["m.dreliane.com"]`) and clear cache after changes.
- Verify marketplace route post-rebuild; investigate only if it impacts core functionality.
- Move toward one-click GitOps by finalizing repo state and documenting a clean deploy path.

---

## Historical Log (high level)
- Hardened entrypoint to respect recommended-project layout, gate DB ops, and run console commands from project root.
- Fixed Dockerfile to avoid invalid entrypoint, align docroot, and add rewrite/ServerName; added config symlink for compatibility.
- Corrected compose volumes and env guards; improved DB healthcheck.
- Resolved installer write issues by ensuring `/var/www/html/config` exists and is writable by `www-data`.
- Addressed reverse-proxy redirect loop by setting `site_url` and trusted proxy/host values in `config/local.php` and clearing cache.
