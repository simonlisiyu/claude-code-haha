#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[devi] $*" >&2
}

cd /app

if [[ ! -f "/app/.env" ]]; then
  log "[error] /app/.env not found. Please mount it with -v <host>/.env:/app/.env:ro"
  exit 1
fi

if [[ "${DEVI_CLI_ONLY:-}" == "1" ]]; then
  if [[ -n "${DEVI_WORKDIR:-}" ]]; then
    if [[ ! -d "$DEVI_WORKDIR" ]]; then
      log "[error] DEVI_WORKDIR is not a directory: $DEVI_WORKDIR"
      exit 1
    fi
    cd "$DEVI_WORKDIR" || exit 1
  fi
  log "DEVI_CLI_ONLY=1: bun CLI only, cwd=$(pwd)"
  exec bun --env-file=/app/.env /app/src/entrypoints/cli.tsx "$@"
fi

if [[ ! -f "/app/litellm_config.yaml" ]]; then
  log "[error] /app/litellm_config.yaml not found. Please mount it with -v <host>/litellm_config.yaml:/app/litellm_config.yaml:ro"
  exit 1
fi

if [[ "${DEVI_PROXY_ONLY:-}" == "1" ]]; then
  log "DEVI_PROXY_ONLY=1: litellm only (foreground), port ${LITELLM_PORT:-4000}"
  exec litellm --config /app/litellm_config.yaml --port "${LITELLM_PORT:-4000}"
fi

cleanup() {
  if [[ -n "${LITELLM_PID:-}" ]] && kill -0 "$LITELLM_PID" 2>/dev/null; then
    kill -TERM "$LITELLM_PID" 2>/dev/null || true
    wait "$LITELLM_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT SIGINT SIGTERM

log "starting litellm (background), port ${LITELLM_PORT:-4000}"
litellm --config /app/litellm_config.yaml --port "${LITELLM_PORT:-4000}" &
LITELLM_PID=$!
log "litellm pid=$LITELLM_PID"

# Keep existing startup behavior while loading mounted env file.
log "starting bun CLI (./src/entrypoints/cli.tsx) …"
if ! bun --env-file=/app/.env ./src/entrypoints/cli.tsx "$@"; then
  EXIT_CODE=$?
  log "bun CLI exited with code $EXIT_CODE"
  cleanup
  exit "$EXIT_CODE"
fi
