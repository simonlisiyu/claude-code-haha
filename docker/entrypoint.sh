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
  # preload.ts: if CALLER_DIR is set, chdir there — must be the mounted workspace.
  # Use bin/claude-haha (same as local): it sets CALLER_DIR from pwd before cd /app + bun.
  if [[ "$#" -eq 0 ]] && [[ ! -t 0 || ! -t 1 ]]; then
    log "[error] CLI mode requires an interactive TTY, but stdin/stdout is not a TTY."
    log "[hint] Use 'docker run -it', do not pipe output (for example '| tee'), and on Windows Git Bash try 'winpty docker run -it ...'."
    log "[hint] If you want headless mode, pass '-p <prompt>' or '--print <prompt>'."
    exit 1
  fi
  export TERM="${TERM:-xterm-256color}"
  export CALLER_DIR="$(pwd)"
  log "DEVI_CLI_ONLY=1: claude-haha, CALLER_DIR=$CALLER_DIR"
  exec /app/bin/claude-haha "$@"
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

# Same as local dev: claude-haha sets CALLER_DIR then runs bun from /app.
log "starting claude-haha (Ink CLI) …"
if ! /app/bin/claude-haha "$@"; then
  EXIT_CODE=$?
  log "CLI exited with code $EXIT_CODE"
  cleanup
  exit "$EXIT_CODE"
fi
