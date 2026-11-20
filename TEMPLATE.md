# WAHA 2026.10 WhatsApp HTTP API (Postgres + Redis): Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **WAHA 2026.10 WhatsApp HTTP API (Postgres + Redis)** (WAHA uses calendar versions; 2026.10.1 pinned) |
| Description | Self-hosted WhatsApp REST API with dashboard, Swagger and API-key auth. (71 chars) |
| Category | Automation |
| Tags | waha, whatsapp, whatsapp-api, whatsapp-http-api, chatbot, n8n, chatwoot, webhooks, messaging |
| Icon | `https://cdn.jsdelivr.net/gh/devlikeapro/waha@2026.10.1/logo.png` |
| Repo | `baranberkay96/waha-railway`, service root `/services/waha` |

## Base market templates

| Code | Active | Image | Notes |
|---|---|---|---|
| `waha` | 457 | `devlikeapro/waha` (latest) | WEBJS, volume `/local`, `/ping` healthcheck, private-domain `WAHA_BASE_URL`, media folder off the volume |
| `waha-n8n` | 67 | `devlikeapro/waha` + n8n + Postgres 17 | Postgres used by n8n only |
| `waha-api` | 63 | `devlikeapro/waha` | same variables as `waha`, no healthcheck |

### Improvements over market templates

- Pinned by digest to 2026.10.1 instead of floating `latest`.
- Sessions, WhatsApp keys and app data in Postgres (open-source build supports it since 2026.6); Redis for apps (Chatwoot).
- GOWS engine by default (much lower RAM than WEBJS); all engines remain selectable.
- `WAHA_BASE_URL` on the public domain so media links in webhooks work; media on the volume.
- Start script: credentials validated (locked instead of printed defaults), "no password" switches ignored, waits for Postgres, invalid values fall back with warnings.

## Pinned versions

| Component | Pin | Released | Checked |
|---|---|---|---|
| WAHA | `devlikeapro/waha:latest-2026.10.1@sha256:2fc1787ddbd343ed2e7d59482846d1b22aa5ca134e29aa8d42d0e88c54e24779` | 2026-10-28 | 2026-11-20 |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Railway | 2026-11-20 |
| Redis | `redis:8.2.11@sha256:b0b01167ff47bc3868e56a967895a26be4230891a1f42a78ab61cdd227accc8d` | — | 2026-11-14 |

## Architecture

WAHA (repo build, public domain 3000, volume `/app/data` for media and the local fallback store) → Postgres (`WHATSAPP_SESSIONS_POSTGRESQL_URL`, `sslmode=disable` on the private network) and Redis (`REDIS_URL`, apps queue). One replica; the volume forces stop-before-start on redeploys so a WhatsApp session never runs twice.

## Services

| Service | Healthcheck | Restart | Volume |
|---|---|---|---|
| WAHA | `/ping`, 900 s | ALWAYS | `/app/data` |
| Postgres | — | ALWAYS | `/var/lib/postgresql/data` |
| Redis | — | ALWAYS | `/data` |

## Resource profile

Measured values in the round-12 report. Estimate: WAHA 0.28 GB idle (GOWS, no session), +30-80 MB per GOWS session, +300-500 MB per WEBJS session; Postgres ~60-120 MB; Redis ~10-30 MB. About $4-8/month idle. Minimum plan: Trial.

## Verification checklist

1. All services SUCCESS, `/ping` 200.
2. `/api/sessions` without key → 401; with key → 200.
3. Dashboard and Swagger ask for basic auth; generated credentials work.
4. Create session `default` → QR code returned (GOWS); session config stored in Postgres.
5. Redeploy WAHA: session list survives.
6. Short dashboard password: service healthy, dashboard locked, log explains.

## Open questions

- Linking a real phone number was not tested (no test number); QR generation is the furthest automated check.
