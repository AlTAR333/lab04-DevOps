#!/usr/bin/env bash
set -uo pipefail
REPO=$(cd "${1:?path to citybike repo}" && pwd); HERE=$(cd "$(dirname "$0")" && pwd); EV="$HERE/evidence"; mkdir -p "$EV"
T() { local s=$SECONDS; "$@"; echo "ELAPSED_SECONDS=$((SECONDS-s))"; }

echo "== Mission 1: node16 vs node20 =="
QA=$(mktemp -d); git clone -q "$(git -C "$REPO" remote get-url ogn)" "$QA/citybike"
{ echo '$ docker run --rm node:16 node server.js'; timeout 20 docker run --rm -v "$QA/citybike":/app -w /app node:16 node server.js 2>&1 | head -15; } > "$EV/m1-node16.txt"
{ echo '$ docker run node:20 node server.js'; timeout 5 docker run --rm -v "$QA/citybike":/app -w /app node:20 node server.js 2>&1 | head -5; } > "$EV/m1-node20.txt"

echo "== Mission 2: naive single stage (no .dockerignore) =="
N=$(mktemp -d); cp -a "$REPO/." "$N/"; rm -f "$N/.dockerignore"; cp "$HERE/Dockerfile.naive" "$N/Dockerfile"
( cd "$N"; { echo '# build 1'; T docker build -t citybike:naive . 2>&1 | tail -5
  docker images citybike:naive --format 'SIZE {{.Repository}}:{{.Tag}} {{.Size}}'
  echo "// touch $(date +%s)" >> public/app.js; echo '# rebuild after 1-line change in public/'
  T docker build -t citybike:naive . 2>&1 | grep -E 'npm ci|CACHED|ELAPSED' | head; } ) > "$EV/m2-naive.txt" 2>&1
docker run --rm citybike:naive sh -c 'ls -a / | head -40; du -sh /node_modules /.git /dist /scripts 2>/dev/null' >> "$EV/m2-naive.txt" 2>&1
docker history citybike:naive --format '{{.Size}}\t{{.CreatedBy}}' | head -8 >> "$EV/m2-naive.txt"

echo "== Mission 3a: cache fixed (+ .dockerignore) =="
C=$(mktemp -d); cp -a "$REPO/." "$C/"; cp "$HERE/Dockerfile.cache" "$C/Dockerfile"
( cd "$C"; { echo '# build 1'; T docker build -t citybike:cache . 2>&1 | tail -3
  docker images citybike:cache --format 'SIZE {{.Repository}}:{{.Tag}} {{.Size}}'
  echo "// touch $(date +%s)" >> public/app.js; echo '# rebuild after 1-line change'
  T docker build -t citybike:cache . 2>&1 | grep -E 'npm ci|CACHED|ELAPSED' | head; } ) > "$EV/m3-cache.txt" 2>&1

echo "== Mission 3b: --omit=dev shortcut =="
S=$(mktemp -d); cp -a "$REPO/." "$S/"; sed 's/RUN npm ci$/RUN npm ci --omit=dev/' "$HERE/Dockerfile.naive" > "$S/Dockerfile"
( cd "$S"; docker build --no-cache -t citybike:shortcut . 2>&1 | tail -12 ) > "$EV/m3-shortcut.txt" 2>&1

echo "== Mission 3c: multi-stage =="
( cd "$REPO"; { echo '# build 1'; T docker build --no-cache -t citybike:v1 . 2>&1 | tail -3
  docker images citybike --format '{{.Repository}}:{{.Tag}} {{.Size}}'
  cp public/app.js /tmp/app.js.bak; echo "// touch $(date +%s)" >> public/app.js; echo '# rebuild after 1-line change'
  T docker build -t citybike:v1 . 2>&1 | grep -E 'npm ci|CACHED|ELAPSED' | head; cp /tmp/app.js.bak public/app.js
  echo '$ docker run --rm citybike:v1 ls node_modules'; docker run --rm citybike:v1 ls node_modules 2>&1
  docker rm -f citybike-test >/dev/null 2>&1; docker run -d --name citybike-test -p 4173:4173 citybike:v1 >/dev/null; sleep 2
  curl -s localhost:4173/health; echo; docker rm -f citybike-test; } ) > "$EV/m3-multistage.txt" 2>&1

echo "== Mission 4: pipeline for v1 =="
( cd "$REPO"; docker rm -f citybike-prod >/dev/null 2>&1; ./scripts/pipeline.sh citybike:v1 ) > "$EV/m4-pipeline-v1.txt" 2>&1; echo "exit=$?" >> "$EV/m4-pipeline-v1.txt"

echo "== Mission 5 part 1: bad push straight to prod =="
( cd "$REPO"; git stash -q 2>/dev/null; git checkout -q feature/v2 && docker build -q -t citybike:v2 . ; git checkout -q main )
{ docker rm -f citybike-prod >/dev/null 2>&1
  docker run -d --name citybike-prod -p 4173:4173 -e APP_ENV=production -e PROD_API_KEY=lab-secret citybike:v2; sleep 3
  echo '$ docker ps -a'; docker ps -a; echo '$ curl /health'; curl -sS -m 5 localhost:4173/health || echo "(no answer)"
  echo; echo '$ docker logs citybike-prod'; docker logs citybike-prod 2>&1 | head -20
  echo; echo '=== ROLLBACK to citybike:v1 ==='; docker rm -f citybike-prod
  docker run -d --name citybike-prod -p 4173:4173 -e APP_ENV=production -e PROD_API_KEY=lab-secret citybike:v1; sleep 2
  docker ps; curl -s localhost:4173/health; echo; } > "$EV/m5-bad-push-and-rollback.txt" 2>&1

echo "== Mission 5 part 2: pipeline blocks v2 =="
( cd "$REPO"; ./scripts/pipeline.sh citybike:v2 ) > "$EV/m5-pipeline-v2.txt" 2>&1; echo "exit=$?" >> "$EV/m5-pipeline-v2.txt"
echo "Done. See $EV"
