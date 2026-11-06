#!/usr/bin/env bash
set -euo pipefail
ROOT=${1:-.}
cd "$ROOT"
echo 'Checking student-authored SDLC source repository ...'
for f in server.js package.json package-lock.json \
   scripts/test-staging.sh scripts/test-uat.sh scripts/test-oat.sh \
   scripts/test-preprod.sh scripts/test-prod.sh; do
  [[ -f "$f" ]] || { echo "MISSING: $f"; exit 1; }
  echo "OK: $f"
done
[[ -d public ]] || { echo 'MISSING: public/'; exit 1; }
node -e 'const p=require("./package.json"); console.log("Available scripts:",p.scripts)'
echo 'PASS: required files present. npm ci + npm run build + HTTP probes still need to be run.'
