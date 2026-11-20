# NOTICE: WAHA 2026.10 WhatsApp HTTP API (Postgres + Redis) template

**This template runs WAHA (devlikeapro/waha).** WAHA is © devlike.pro and contributors, licensed under the Apache License 2.0. This is a community template; it is not affiliated with or endorsed by devlike.pro, Meta, WhatsApp or Railway.

## Licence and edition

- The template uses the open-source image `devlikeapro/waha` (repository `LICENSE`: Apache-2.0, checked at tag `2026.10.1`). It does not use the commercial `devlikeapro/waha-plus` image or any paid key. Upstream's README states that since 2026.6 the former Plus features are part of the main image ("WAHA 2026.6 - Plus is now Core").
- WhatsApp engines in the image (GOWS, NOWEB, WEBJS) are unofficial WhatsApp Web clients. Using them can violate WhatsApp's terms and get a number banned; the README states this risk, and the user decides whether to accept it. The same wording approach is used in our Evolution API template.

## Components

| Component | Source | License | How it is used |
|---|---|---|---|
| WAHA 2026.10.1 | https://github.com/devlikeapro/waha, image `devlikeapro/waha:latest-2026.10.1@sha256:2fc1787ddbd343ed2e7d59482846d1b22aa5ca134e29aa8d42d0e88c54e24779` | Apache-2.0 | Base image, unmodified |
| Chromium, Node.js, Go GOWS binary and other packages inside the image | bundled by the WAHA image | each package's own license | Run by WAHA |
| WAHA logo (icon) | `logo.png` at tag `2026.10.1` of devlikeapro/waha | Apache-2.0 repository content; the name and logo belong to devlike.pro | Marketplace icon, unmodified |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | PostgreSQL License | Session store |
| Redis 8.2.11 | `redis:8.2.11` (Docker Official Image, digest-pinned) | RSALv2 / SSPLv1 / AGPLv3 (Redis 8) | Apps job queue |

## Files written for this template

`services/waha/Dockerfile` and `services/waha/railway-start.sh` were written for this template. The script validates the variables, waits for Postgres and then runs the image's own `/entrypoint.sh`; WAHA's files are not modified. They are offered under the Apache License 2.0.

## Upstream files checked

At tag `2026.10.1` (2026-10-28): `Dockerfile` (tini, `/entrypoint.sh`, port 3000, root user), `entrypoint.sh` (API key hashing, xvfb only for WEBJS), `.env.example`, `docker-compose.yaml`, `src/core/auth/config.ts` (common or empty secrets are replaced by generated values that are printed in the log), `src/config.service.ts` (`PORT`, `WHATSAPP_SESSIONS_POSTGRESQL_URL`, `WAHA_WORKER_RESTART_SESSIONS` default true), `src/core/manager.core.ts` (Postgres/Mongo/local session storage in the open-source build), `src/core/storage/psql/PsqlConnectionConfig.ts` (`sslmode=disable`), `src/apps/app_sdk/env.ts` (apps; queue apps need Redis), `src/api/ping.controller.ts`, `README.md`, `LICENSE`.

## Market templates reviewed

`waha` (457 active projects), `waha-n8n` (67) and `waha-api` (63), read on 2026-11-20. All use the untagged `devlikeapro/waha` image (floating `latest`), WEBJS, local storage, and `WAHA_BASE_URL` pointing at the private domain (media links unusable from outside). Nothing was copied from them.
