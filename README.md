# Deploy and Host WAHA with Railway

WAHA (WhatsApp HTTP API) is a self-hosted REST API for WhatsApp: link a number by QR code, then send and receive messages, media, groups, contacts and status updates over HTTP, with webhooks for incoming events. This template runs WAHA 2026.10.1 with Postgres session storage, Redis for its apps, the dashboard and Swagger UI, all behind generated credentials.

> This template runs WAHA by devlike.pro (Apache-2.0). It is a community template, not affiliated with devlike.pro, Meta or WhatsApp.

## About Hosting WAHA

WAHA keeps a long-lived WhatsApp connection per session (one session = one phone number) and exposes it as an HTTP API with an OpenAPI description. Since version 2026.6 the open-source image includes the former "Plus" features: multiple sessions, Postgres storage, media storage options and apps.

This template stores sessions, WhatsApp keys and app data in Postgres, so they survive redeploys and volume loss, and uses Redis for the job queue of apps such as the Chatwoot integration. Received media files go to a volume. The API needs the generated API key on every request; the dashboard (`/dashboard`) and Swagger UI (`/`) need a username and password. The default engine is GOWS, which needs far less memory than the browser-based WEBJS engine.

## Common Use Cases

- Send order updates, reminders and support replies from your backend to customers who contacted you
- Connect a WhatsApp number to Chatwoot as a shared support inbox (built-in Chatwoot app)
- Trigger n8n, Make or your own code from incoming WhatsApp messages via webhooks
- Build WhatsApp bots and AI assistants on top of a plain HTTP API

## Dependencies for WAHA Hosting

- WAHA service (repo build on the official `devlikeapro/waha` image, pinned by digest, volume at `/app/data`)
- Postgres 18 (Railway image, volume)
- Redis 8.2 with append-only persistence (volume)

### Deployment Dependencies

- [WAHA documentation](https://waha.devlike.pro/docs/overview/introduction/)
- [WAHA on GitHub](https://github.com/devlikeapro/waha) (Apache-2.0)
- [WhatsApp Terms of Service](https://www.whatsapp.com/legal/terms-of-service) and [WhatsApp Business Messaging Policy](https://business.whatsapp.com/policy)
- [Railway Fair Use Policy](https://railway.com/legal/fair-use)

### Implementation Details

| Service | Image | Purpose |
|---|---|---|
| WAHA | `devlikeapro/waha:latest-2026.10.1` + start script | REST API, dashboard, Swagger UI, WhatsApp sessions |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18` | Sessions, WhatsApp keys, app data |
| Redis | `redis:8.2.11` (AOF on) | Job queue for WAHA apps (Chatwoot) |

**First steps**

1. Open the WAHA service, Variables tab, and copy `WAHA_API_KEY`, `WAHA_DASHBOARD_USERNAME` and `WAHA_DASHBOARD_PASSWORD`.
2. Open `https://{your-domain}/dashboard`, log in, and add the server `https://{your-domain}` with the API key.
3. Start the `default` session and scan the QR code with WhatsApp (Settings, Linked devices).
4. Or use the API: `POST /api/sessions` with header `X-Api-Key: {key}` and body `{"name":"default","start":true}`, then `GET /api/default/auth/qr` for the QR code.
5. Send a message: `POST /api/sendText` with `{"session":"default","chatId":"{country code + number}@c.us","text":"Hello"}`.

Set a webhook per session in the dashboard or with `WHATSAPP_HOOK_URL` for all sessions. Services in this Railway project can call `http://waha.railway.internal:3000` over the private network. `GET /ping` is the healthcheck; every other route needs the key.

**Security defaults**

- API key (48 characters) and dashboard password (24 characters) are generated; Swagger uses the dashboard password unless you change it.
- An API key shorter than 16 characters or a password shorter than 12, an empty value or one with spaces locks that part with a random secret instead of falling back to WAHA's printed default; the log says how to fix it. WAHA's `*_NO_API_KEY` / `*_NO_PASSWORD` switches are ignored.

**Engines and resources**

`WHATSAPP_DEFAULT_ENGINE` selects the engine for new sessions: GOWS (default, Go, lightweight), NOWEB (Node.js) or WEBJS (a Chromium per session). Measured on Railway without an active WhatsApp session: WAHA 0.28 GB, Postgres 0.12 GB and Redis 0.02 GB idle. Session memory depends on the selected engine; QR pairing was not exercised in this release check. It fits the Trial plan (1 GB per service); WEBJS needs roughly 300-500 MB per session more.

**Scaling and upgrades**

Run one replica: two replicas would open the same WhatsApp sessions twice. The volume makes Railway stop the old deployment before starting the new one, which avoids that during redeploys. To upgrade, change `WAHA_IMAGE` (tag and digest) in `services/waha/Dockerfile` of your fork.

**Risks you accept with WhatsApp Web engines**

- WAHA connects through WhatsApp Web protocols (GOWS, NOWEB, WEBJS). This is not an official WhatsApp API and is not provided or endorsed by Meta or WhatsApp; WhatsApp can restrict or ban numbers that use it, especially new numbers or numbers that send many messages.
- You must follow WhatsApp's Terms of Service and Business Messaging Policy. Do not send spam, bulk or unsolicited messages; message only people who agreed to hear from you. Railway's Fair Use Policy also forbids abusive bots, and Railway may remove such deployments.
- Use a number you can afford to lose for testing. For business-critical or high-volume messaging, use Meta's official WhatsApp Cloud API.

### Why Deploy WAHA on Railway?

Railway runs WAHA, Postgres and Redis as one project with private networking, volumes, HTTPS and logs, so you get a working WhatsApp API in minutes without managing servers, and pay only for what the three services use.
