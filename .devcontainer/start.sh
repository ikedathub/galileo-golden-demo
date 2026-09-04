#!/usr/bin/env bash
# Runs on every Codespace start: database up, secrets refreshed, index present.
set -uo pipefail

bash .devcontainer/local_db.sh || echo "⚠️  database startup failed"
python3 .devcontainer/bootstrap_secrets.py --force
python3 .devcontainer/ensure_index.py bank || echo "⚠️  index build failed"

# Serve the app from a detached process so port 8501 stays forwarded for the
# life of the Codespace instead of only while a terminal holds the command.
if curl -fsS -o /dev/null http://localhost:8501 2>/dev/null; then
  echo "Streamlit already listening on port 8501."
else
  mkdir -p .devcontainer/logs
  # `python3 -m streamlit` works even when pip's user bin directory is missing
  # from PATH, which a bare `streamlit` call would not.
  nohup python3 -m streamlit run app.py \
    --server.port 8501 \
    --server.address 0.0.0.0 \
    --server.headless true \
    >.devcontainer/logs/streamlit.log 2>&1 &
fi

# Report whether the port is actually serving, because Codespaces only forwards
# (and only answers with something other than 404) once something listens.
for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null http://localhost:8501 2>/dev/null; then
    STREAMLIT_UP=1
    break
  fi
  sleep 2
done

if [ "${STREAMLIT_UP:-0}" = "1" ]; then
  cat <<EOF

Streamlit is serving on port 8501.

Open it at:

    https://${CODESPACE_NAME:-<codespace>}-8501.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}

EOF
else
  echo
  echo "⚠️  Streamlit is not listening on port 8501. Last log lines:"
  tail -n 20 .devcontainer/logs/streamlit.log 2>/dev/null
  echo
fi

cat <<'EOF'
Restart the app after code changes with:

    pkill -f 'streamlit run' ; bash .devcontainer/start.sh

Other domains (healthcare / insurance / restaurant) need their index built once:

    python helpers/setup_vectordb.py healthcare

EOF

exit 0
