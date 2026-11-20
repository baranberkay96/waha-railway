#!/bin/bash
# Railway start wrapper for WAHA. Validates the deploy-form variables, then execs the
# image's /entrypoint.sh. Never exits because of a variable value (STANDARD 8.29), and
# never leaves the API, dashboard or Swagger without credentials.
set -u

log() { echo "railway-start: $*"; }
random_secret() { tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 48; }

# secret_var NAME MIN WHAT: keep the value if it is MIN-512 characters without
# whitespace, otherwise lock it with a random value nobody knows.
secret_var() {
  local name="$1" min="$2" what="$3" value="${!1-}"
  local len=${#value}
  if [ "$len" -lt "$min" ] || [ "$len" -gt 512 ] || [[ "$value" =~ [[:space:][:cntrl:]] ]]; then
    log "WARNING: $name is empty, shorter than $min or longer than 512 characters, or contains spaces."
    log "         The $what is LOCKED with a random secret nobody knows. Fix: set a valid value in the Variables tab and redeploy."
    export "$name=$(random_secret)"
  fi
}
user_var() {
  local name="$1" value="${!1-}"
  if ! [[ "$value" =~ ^[A-Za-z0-9._@-]{1,64}$ ]]; then
    log "WARNING: $name is empty or has characters other than letters, digits and . _ @ -; using 'admin'"
    export "$name=admin"
  fi
}
bool_word() { # prints True/False
  case "${1:-}" in 1|true|TRUE|True|yes|YES|Yes|on|ON|On) echo True ;; 0|false|FALSE|False|no|NO|No|off|OFF|Off) echo False ;; *) echo "${2}" ;; esac
}

# --- Port ---
if [[ "${PORT:-}" =~ ^[0-9]{1,5}$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then :; else
  [ -n "${PORT:-}" ] && log "WARNING: PORT='${PORT}' is not a valid port, using 3000"
  export PORT=3000
fi
unset WHATSAPP_API_PORT

# --- Credentials: never allow the "no password / no key" switches ---
for switch in WAHA_NO_API_KEY WAHA_DASHBOARD_NO_PASSWORD WHATSAPP_SWAGGER_NO_PASSWORD; do
  if [ -n "${!switch-}" ]; then log "WARNING: $switch is ignored on this template; credentials are always required."; fi
  unset "$switch"
done
if [ -n "${WHATSAPP_API_KEY:-}" ] && [ -z "${WAHA_API_KEY:-}" ]; then export WAHA_API_KEY="$WHATSAPP_API_KEY"; fi
unset WHATSAPP_API_KEY WAHA_API_KEY_PLAIN
case "${WAHA_API_KEY:-}" in
  sha512:*) [[ "$WAHA_API_KEY" =~ ^sha512:[0-9a-f]{128}$ ]] || secret_var WAHA_API_KEY 999 "API" ;;
  *) secret_var WAHA_API_KEY 16 "API" ;;
esac
# WAHA apps call the API themselves and need the plain key (the image's entrypoint
# replaces WAHA_API_KEY with its sha512 hash). A key given as a hash cannot serve them.
if [[ "$WAHA_API_KEY" == sha512:* ]]; then
  if [ "$(bool_word "${WAHA_APPS_ENABLED:-}" False)" = True ]; then
    log "WARNING: WAHA_API_KEY is given as a sha512 hash, so WAHA apps (Chatwoot, MCP) cannot call the API; apps are turned off."
  fi
  export WAHA_APPS_ENABLED=False
else
  export WAHA_API_KEY_PLAIN="$WAHA_API_KEY"
fi
user_var WAHA_DASHBOARD_USERNAME
secret_var WAHA_DASHBOARD_PASSWORD 12 "dashboard"
user_var WHATSAPP_SWAGGER_USERNAME
secret_var WHATSAPP_SWAGGER_PASSWORD 12 "Swagger UI"
export WAHA_DASHBOARD_ENABLED="$(bool_word "${WAHA_DASHBOARD_ENABLED:-}" True)"
export WHATSAPP_SWAGGER_ENABLED="$(bool_word "${WHATSAPP_SWAGGER_ENABLED:-}" True)"

# --- Engine ---
case "${WHATSAPP_DEFAULT_ENGINE:-GOWS}" in
  GOWS|NOWEB|WEBJS) export WHATSAPP_DEFAULT_ENGINE="${WHATSAPP_DEFAULT_ENGINE:-GOWS}" ;;
  gows|noweb|webjs) export WHATSAPP_DEFAULT_ENGINE="$(echo "$WHATSAPP_DEFAULT_ENGINE" | tr 'a-z' 'A-Z')" ;;
  *) log "WARNING: WHATSAPP_DEFAULT_ENGINE='${WHATSAPP_DEFAULT_ENGINE}' is not GOWS, NOWEB or WEBJS; using GOWS"; export WHATSAPP_DEFAULT_ENGINE=GOWS ;;
esac

# --- Storage paths on the volume ---
DATA="${RAILWAY_VOLUME_MOUNT_PATH:-/app/data}"
export WHATSAPP_FILES_FOLDER="${WHATSAPP_FILES_FOLDER:-$DATA/media}"
export WAHA_LOCAL_STORE_BASE_DIR="${WAHA_LOCAL_STORE_BASE_DIR:-$DATA/sessions}"
mkdir -p "$WHATSAPP_FILES_FOLDER" "$WAHA_LOCAL_STORE_BASE_DIR" 2>/dev/null || log "WARNING: could not create the data folders under $DATA"
rm -rf "$DATA/lost+found" 2>/dev/null || true
case "${WHATSAPP_FILES_LIFETIME:-}" in
  ''|*[!0-9]*) [ -n "${WHATSAPP_FILES_LIFETIME:-}" ] && log "WARNING: WHATSAPP_FILES_LIFETIME is not a number of seconds, using 180"; export WHATSAPP_FILES_LIFETIME=180 ;;
esac

# --- Postgres session storage: wait for the database, WAHA exits if it is unreachable ---
if [ -n "${WHATSAPP_SESSIONS_POSTGRESQL_URL:-}" ]; then
  if node -e 'new URL(process.env.WHATSAPP_SESSIONS_POSTGRESQL_URL)' 2>/dev/null; then
    host_port="$(node -e 'const u=new URL(process.env.WHATSAPP_SESSIONS_POSTGRESQL_URL);console.log(u.hostname.replace(/^\[|\]$/g,"")+" "+(u.port||5432))')"
    host="${host_port% *}"; port="${host_port#* }"
    waited=0
    until node -e 'const s=require("net").connect({host:process.argv[1],port:+process.argv[2]},()=>{s.end();process.exit(0)});s.on("error",()=>process.exit(1));setTimeout(()=>process.exit(1),4000)' "$host" "$port"; do
      if [ "$waited" -ge 600 ]; then log "WARNING: Postgres at ${host}:${port} is still unreachable after 600 s; starting anyway"; break; fi
      [ $((waited % 30)) -eq 0 ] && log "waiting for Postgres at ${host}:${port}"
      sleep 3; waited=$((waited + 3))
    done
    log "session storage: Postgres (${host}:${port})"
  else
    log "WARNING: WHATSAPP_SESSIONS_POSTGRESQL_URL is not a valid URL; sessions are stored on the volume instead"
    unset WHATSAPP_SESSIONS_POSTGRESQL_URL
  fi
else
  log "session storage: volume (${WAHA_LOCAL_STORE_BASE_DIR})"
fi

# --- Apps (Chatwoot integration and others) need Redis for their job queue ---
if [ -z "${REDIS_URL:-}" ] && [ "$(bool_word "${WAHA_APPS_ENABLED:-}" False)" = True ]; then
  log "WARNING: WAHA_APPS_ENABLED is on but REDIS_URL is empty; apps that need a queue (Chatwoot) will not work"
fi

log "WAHA on port ${PORT}, engine ${WHATSAPP_DEFAULT_ENGINE}, dashboard ${WAHA_DASHBOARD_ENABLED} (/dashboard), Swagger ${WHATSAPP_SWAGGER_ENABLED} (/)"
exec /entrypoint.sh "$@"
