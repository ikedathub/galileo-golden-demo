#!/usr/bin/env bash
# Start a pgvector container inside the Codespace.
#
# Skipped entirely when POSTGRES_HOST is set, so pointing the app at a managed
# database (Supabase, Neon, RDS) is just a matter of adding Codespaces secrets.
set -euo pipefail

CONTAINER=golden-demo-postgres
PW_FILE="$HOME/.golden-demo-db-password"

if [ -n "${POSTGRES_HOST:-}" ]; then
  echo "ℹ️  POSTGRES_HOST is set — using the external database, no local container."
  exit 0
fi

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"
}

# The password lives only on this machine. If it was lost, the existing
# container can no longer be authenticated against, so recreate both together.
if [ ! -f "$PW_FILE" ] && container_exists; then
  echo "⚠️  Database password file missing — recreating the container."
  docker rm -f "$CONTAINER" >/dev/null
fi

if [ ! -f "$PW_FILE" ]; then
  (umask 077; openssl rand -hex 24 > "$PW_FILE")
fi
PW="$(cat "$PW_FILE")"

if ! container_exists; then
  echo "→ Starting pgvector..."
  docker run -d --name "$CONTAINER" \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD="$PW" \
    -e POSTGRES_DB=vectordb \
    -p 127.0.0.1:5432:5432 \
    --restart unless-stopped \
    pgvector/pgvector:pg16 >/dev/null
elif [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" != "true" ]; then
  docker start "$CONTAINER" >/dev/null
fi

# pg_isready answers from the temporary server the image runs while
# initialising, before the database exists, so query the database itself.
for _ in $(seq 1 60); do
  if docker exec "$CONTAINER" psql -U postgres -d vectordb -c 'SELECT 1' \
      >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

docker exec "$CONTAINER" psql -U postgres -d vectordb \
  -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null
echo "✓ pgvector ready on localhost:5432"
