#!/usr/bin/env bash
set -euo pipefail
printf '\n=== SDLC/Docker Lab 04 preflight ===\n'
for tool in git node npm docker curl bash; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "MISSING TOOL: $tool"; exit 1
  fi
  printf 'OK: %s\n' "$tool"
done
if ! docker info >/dev/null 2>&1; then
  echo 'FAIL: Start the Docker daemon, then rerun.'; exit 1
fi
printf 'Node: '; node --version
printf 'npm: '; npm --version
printf 'Git: '; git --version
printf 'Docker server: '; docker version --format '{{.Server.Version}}'
echo 'PASS: tool checks. Next: verify the external student-authored starter repository files.'
