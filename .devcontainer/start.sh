#!/usr/bin/env bash
# Runs on every Codespace start: database up, secrets refreshed, index present.
set -uo pipefail

bash .devcontainer/local_db.sh || echo "⚠️  database startup failed"
python3 .devcontainer/bootstrap_secrets.py --force
python3 .devcontainer/ensure_index.py bank || echo "⚠️  index build failed"

cat <<'EOF'

Ready. Start the app with:

    streamlit run app.py

Other domains (healthcare / insurance / restaurant) need their index built once:

    python helpers/setup_vectordb.py healthcare

EOF

exit 0
