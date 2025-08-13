# Development Log — Mautic 6 on Coolify

This log summarizes the work completed to achieve a reliable, GitOps-friendly Mautic 6 deployment on Coolify. It captures changes, decisions, and the current state for reproducibility.

## Scope
- Base image: `mautic/mautic:6-apache`
- Project layout: Mautic 6 recommended-project (web root in `docroot/`)
- Orchestration: Docker Compose (Coolify builds/deploys)
- Database: Percona 8.0

## Timeline (high-level)
- Harden Docker entrypoint for recommended-project paths; defer DB ops until real install exists.
- Fix Dockerfile build/runtime issues; correct CMD; set Apache DocumentRoot to `docroot`; enable rewrite.
- Correct compose volumes (config/media/logs/cache) and enforce required envs with `${VAR:?required}`.
- Resolve installer write/permissions; ensure config path at project root and symlink under docroot.
- Address reverse-proxy behavior via `site_url`, trusted proxies/hosts, and cache clear.
- App now installs and reaches the dashboard; SES setup pending; cron via Coolify Scheduled Jobs.

## Changes by File
- `Dockerfile`
  - Multi-stage with Composer (`--no-dev --no-scripts --ignore-platform-reqs`).
  - Copy only `vendor/` to runtime image.
  - Set `APACHE_DOCUMENT_ROOT=/var/www/html/docroot`; update Apache configs.
  - Enable `mod_rewrite`; set default `ServerName localhost`.
  - Add `docroot/config -> ../config` symlink.
  - Fix `CMD` to `apache2-foreground` (removed invalid `/docker-entrypoint.sh`).

- `docker/entrypoint.sh`
  - Define `APP_DIR=/var/www/html`, `WEB_DIR=$APP_DIR/docroot`.
  - Detect install via `APP_DIR/config/local.php`; treat known stub as NOT installed.
  - Create and chown `APP_DIR/config`; ensure `var/` dirs exist and are writable.
  - Gate DB wait/migrations/cache/assets until installed; then run `bin/console` tasks.
  - Hand off to base `docker-php-entrypoint` for robust Apache/PHP init.

- `docker-compose.yaml`
  - DB: Percona 8.0, `mysqladmin ping` healthcheck with sensible timing.
  - App: build from `.`; depends_on DB health.
  - Volumes:
    - `mautic_config -> /var/www/html/config` (project root)
    - `mautic_media -> /var/www/html/docroot/media`
    - `mautic_logs  -> /var/www/html/docroot/var/logs`
    - `mautic_cache -> /var/www/html/docroot/var/cache`
  - Env guards: `${VAR:?required}` for DB, `APP_SECRET`, `MAUTIC_SITE_URL`.
  - Trust proxies env retained (post-install values live in `config/local.php`).

- `docs/coolify.md`
  - Manual Coolify setup steps (envs, volumes, build/deploy).
  - Cron via Coolify Scheduled Jobs with `php bin/console` commands.
  - Notes on SES SMTP configuration and troubleshooting.

## Key Decisions & Rationale
- Defer all DB operations until a real (non-stub) `local.php` exists to prevent migrations on an empty schema.
- Keep build lean: Composer without scripts; generate assets at runtime.
- Align Apache DocumentRoot to `docroot` per recommended-project; enable rewrite.
- Persist config at project root (`/var/www/html/config`) with a symlink at `docroot/config` for compatibility.
- Use Coolify Scheduled Jobs for cron (no in-container cron), keeping runtime behavior explicit and reproducible.
- Prefer AWS SES for SMTP; plan to integrate bounces/complaints via SNS (avoids PHP IMAP).
- Remove IaC for Coolify due to provider limitations; favor clear manual steps + GitOps.

## Current State
- Installer completed; dashboard accessible.
- DB connectivity validated via `doctrine:query:sql` in-container.
- Entrypoint gates DB wait/migrations/cache/assets appropriately; `INITIAL_SKIP_DB_WAIT` should now be `false` for restarts.
- Apache running with `docroot` and rewrite enabled; default `ServerName` set.
- Cron to be configured in Coolify: segments, campaigns rebuild/trigger, broadcasts, webhooks, emails (if queued).
- SES SMTP can be configured in Mautic UI (TLS 587 using SES SMTP creds).
- Preference: implement SES SNS bridge for bounces/complaints (no IMAP dependency).

## Next Steps
- Configure Coolify Scheduled Jobs (copy commands from docs) and validate.
- Set up SES SMTP in Mautic and send a test email.
- Implement optional SNS bridge service and document SES topic/subscription (if chosen).
- Clean repo: remove Terraform/Coolify automation artifacts; ensure docs reflect manual Coolify + GitOps flow.
- Verify `config/local.php` contains:
  - `site_url` = `https://m.dreliane.com`
  - `trusted_proxies` = `["0.0.0.0/0"]`
  - `trusted_hosts`   = `["m.dreliane.com"]`
  - Then `php bin/console cache:clear`.

## One‑Click GitOps Goal
- Aim: minimal manual steps; push-to-deploy via Coolify with enforced env guards and clear runtime behaviors.
- Deliverables pending: SNS bridge (optional), repo cleanup, and final documentation tweaks.
