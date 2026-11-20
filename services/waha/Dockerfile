# syntax=docker/dockerfile:1
#
# WAHA (WhatsApp HTTP API) 2026.10.1 for Railway.
#
# The official image, unchanged, plus one start script (railway-start.sh) that checks
# the deploy-form values before WAHA reads them: an unusable API key or password
# locks the API/dashboard with a random secret instead of opening it, WAHA's
# "no password" switches are ignored, and invalid values fall back to defaults with a
# warning instead of failing the deploy. It then runs the image's own entrypoint.
#
# Pin (checked 2026-11-20 on Docker Hub): devlikeapro/waha:latest-2026.10.1 index
# digest, pushed 2026-10-28 (latest stable release). This is the open-source image
# (Apache-2.0, all engines: WEBJS with Chromium, NOWEB, GOWS); since 2026.6 the former
# "Plus" features are part of it.
ARG WAHA_IMAGE=devlikeapro/waha:latest-2026.10.1@sha256:2fc1787ddbd343ed2e7d59482846d1b22aa5ca134e29aa8d42d0e88c54e24779
FROM ${WAHA_IMAGE}

COPY --chmod=0755 railway-start.sh /usr/local/bin/railway-start

# Sessions and app data live in Postgres; media files on the Railway volume at
# /app/data (no VOLUME instruction: Railway rejects it).
EXPOSE 3000
ENTRYPOINT ["/usr/bin/tini", "-s", "--", "/usr/local/bin/railway-start"]
CMD []
