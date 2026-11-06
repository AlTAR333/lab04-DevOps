#!/usr/bin/env bash

set -euo pipefail

IMAGE="${1:?usage: scripts/pipeline.sh <image-tag>}"
cd "$(dirname "$0")/.."

PROD_API_KEY="${PROD_API_KEY:-lab-secret}"
GATE_NAME=citybike-gate
PROD_NAME=citybike-prod
GATE_PORT=4174    
PROD_PORT=4173    
HEALTH_TIMEOUT=30

cleanup() { docker rm -f "$GATE_NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

fail() { echo "PIPELINE STOPPED: $*" >&2; exit 1; }

wait_healthy() {
  local name=$1 url=$2 deadline=$((SECONDS + HEALTH_TIMEOUT))
  until curl -sf "$url/health" >/dev/null 2>&1; do
    if [ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || echo false)" != "true" ]; then
      echo "--- container $name is not running; logs:" >&2
      docker logs "$name" 2>&1 | tail -n 20 >&2 || true
      return 1
    fi
    if (( SECONDS >= deadline )); then
      echo "--- timeout after ${HEALTH_TIMEOUT}s waiting for $url/health; logs:" >&2
      docker logs "$name" 2>&1 | tail -n 20 >&2 || true
      return 1
    fi
    sleep 1
  done
}

# run_gate <gate> <app_env> <with_key:yes|no>
run_gate() {
  local gate=$1 app_env=$2 with_key=$3
  local url="http://localhost:${GATE_PORT}"
  echo; echo "=== GATE: ${gate} (APP_ENV=${app_env}) image=${IMAGE} ==="
  docker rm -f "$GATE_NAME" >/dev/null 2>&1 || true                       # 1. leftovers
  local args=(-d --name "$GATE_NAME" -p "${GATE_PORT}:4173" -e "APP_ENV=${app_env}")
  [ "$with_key" = yes ] && args+=(-e "PROD_API_KEY=${PROD_API_KEY}")
  docker run "${args[@]}" "$IMAGE" >/dev/null                            # 2. start
  wait_healthy "$GATE_NAME" "$url" || fail "${gate}: container never became healthy"   # 3. poll
  TARGET_URL="$url" IMAGE_NAME="$IMAGE" "./scripts/test-${gate}.sh" \
    || fail "${gate} gate FAILED"                                        # 4. test
  docker rm -f "$GATE_NAME" >/dev/null                                   # 5. clean up
  echo "=== GATE ${gate}: PASSED ==="
}

run_gate staging staging       no
run_gate uat     uat           no
run_gate oat     oat           no
run_gate preprod preprod       yes

echo; echo "=== GATE: prod (APP_ENV=production) image=${IMAGE} ==="
docker rm -f "$PROD_NAME" >/dev/null 2>&1 || true
docker run -d --name "$PROD_NAME" -p "${PROD_PORT}:4173" \
  -e APP_ENV=production -e "PROD_API_KEY=${PROD_API_KEY}" "$IMAGE" >/dev/null
wait_healthy "$PROD_NAME" "http://localhost:${PROD_PORT}" \
  || { docker rm -f "$PROD_NAME" >/dev/null 2>&1 || true; fail "prod: container never became healthy"; }
TARGET_URL="http://localhost:${PROD_PORT}" ./scripts/test-prod.sh \
  || { docker rm -f "$PROD_NAME" >/dev/null 2>&1 || true; fail "prod gate FAILED"; }
echo "=== GATE prod: PASSED === ($PROD_NAME left running on :${PROD_PORT})"
echo; echo "PIPELINE PASSED for ${IMAGE}"
