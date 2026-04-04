#!/usr/bin/env bash
set -euo pipefail

cd /app

if [[ ! -f "/app/.env" ]]; then
  echo "[error] /app/.env not found. Please mount it with -v <host>/.env:/app/.env:ro"
  exit 1
fi

if [[ ! -f "/app/litellm_config.yaml" ]]; then
  echo "[error] /app/litellm_config.yaml not found. Please mount it with -v <host>/litellm_config.yaml:/app/litellm_config.yaml:ro"
  exit 1
fi

cleanup() {
  if [[ -n "${LITELLM_PID:-}" ]] && kill -0 "$LITELLM_PID" 2>/dev/null; then
    kill -TERM "$LITELLM_PID" 2>/dev/null || true
    wait "$LITELLM_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT SIGINT SIGTERM

litellm --config /app/litellm_config.yaml --port "${LITELLM_PORT:-4000}" &
LITELLM_PID=$!

# Keep existing startup behavior while loading mounted env file.
if ! bun --env-file=/app/.env ./src/entrypoints/cli.tsx "$@"; then
  EXIT_CODE=$?
  cleanup
  exit "$EXIT_CODE"
fi
