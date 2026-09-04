#!/usr/bin/env bash
# Runs on every Codespace start: database up, secrets refreshed, index present.
set -uo pipefail

bash .devcontainer/local_db.sh || echo "⚠️  database startup failed"
python3 .devcontainer/bootstrap_secrets.py --force
python3 .devcontainer/ensure_index.py bank || echo "⚠️  index build failed"

# Serve the app from a detached process so port 8501 stays forwarded for the
# life of the Codespace instead of only while a terminal holds the command.
if curl -fsS -o /dev/null http://localhost:8501 2>/dev/null; then
  echo "Streamlit already running on port 8501."
else
  mkdir -p .devcontainer/logs
  nohup streamlit run app.py \
    --server.port 8501 \
    --server.address 0.0.0.0 \
    --server.headless true \
    >.devcontainer/logs/streamlit.log 2>&1 &
  echo "Streamlit starting; logs in .devcontainer/logs/streamlit.log"
fi

cat <<'EOF'

Ready. Open port 8501 from the PORTS tab once it is forwarded.

Restart the app after code changes with:

    pkill -f 'streamlit run' ; bash .devcontainer/start.sh

Other domains (healthcare / insurance / restaurant) need their index built once:

    python helpers/setup_vectordb.py healthcare

EOF

exit 0
