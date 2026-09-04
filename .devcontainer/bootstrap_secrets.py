#!/usr/bin/env python3
"""Generate .streamlit/secrets.toml from environment variables.

Codespaces injects repository/user secrets as environment variables, so the
Streamlit secrets file is rebuilt on every start instead of being stored in the
repository. Values are never printed — only whether each key was found.

Database resolution:
  POSTGRES_HOST set  -> use the external database described by the env vars
  POSTGRES_HOST unset -> use the pgvector container started by local_db.sh
"""
import os
import stat
import sys
from pathlib import Path

SECRETS_PATH = Path(".streamlit/secrets.toml")
LOCAL_DB_PASSWORD_FILE = Path.home() / ".golden-demo-db-password"

REQUIRED = {
    "GALILEO_API_KEY": "galileo_api_key",
    "OPENAI_API_KEY": "openai_api_key",
}

RECOMMENDED = {
    "GALILEO_CONSOLE_URL": "galileo_console_url",
}

# The Splunk-branded console hands out SPLUNK_AO_* variable names, so accept
# either spelling for the same secret.
ALIASES = {
    "GALILEO_API_KEY": "SPLUNK_AO_API_KEY",
    "GALILEO_CONSOLE_URL": "SPLUNK_AO_CONSOLE_URL",
    "GALILEO_PROJECT": "SPLUNK_AO_PROJECT",
}

OPTIONAL = {
    "GALILEO_PROJECT": "galileo_project",
    "GALILEO_API_URL": "galileo_api_url",
    "OPENAI_DEFAULT_CHAT_MODEL": "openai_default_chat_model",
    "OPENAI_EMBEDDING_MODEL": "openai_embedding_model",
    "AGENT_CONTROL_AGENT_NAME": "agent_control_agent_name",
    "ADMIN_KEY": "admin_key",
}

EXTERNAL_DB = {
    "POSTGRES_HOST": "postgres_host",
    "POSTGRES_PORT": "postgres_port",
    "POSTGRES_USER": "postgres_user",
    "POSTGRES_PASSWORD": "postgres_password",
    "POSTGRES_DB": "postgres_db",
    "POSTGRES_SSLMODE": "postgres_sslmode",
}


def toml_escape(value: str) -> str:
    out = value.replace("\\", "\\\\").replace('"', '\\"')
    return out.replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")


def env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value and name in ALIASES:
        value = os.environ.get(ALIASES[name], "").strip()
    return value


def database_entries() -> dict:
    """Point at the external database if configured, else the local container."""
    if env("POSTGRES_HOST"):
        entries = {key: env(name) for name, key in EXTERNAL_DB.items() if env(name)}
        entries.setdefault("postgres_port", "5432")
        entries.setdefault("postgres_user", "postgres")
        entries.setdefault("postgres_db", "postgres")
        print("→ database: external (POSTGRES_HOST)")
        return entries

    if not LOCAL_DB_PASSWORD_FILE.exists():
        print(f"⚠️  {LOCAL_DB_PASSWORD_FILE} not found — run .devcontainer/local_db.sh first")
        return {}

    print("→ database: local pgvector container")
    return {
        "postgres_host": "localhost",
        "postgres_port": "5432",
        "postgres_user": "postgres",
        "postgres_password": LOCAL_DB_PASSWORD_FILE.read_text().strip(),
        "postgres_db": "vectordb",
    }


def main() -> int:
    force = "--force" in sys.argv

    if SECRETS_PATH.exists() and not force:
        print(f"✓ {SECRETS_PATH} already exists (use --force to regenerate)")
        return 0

    entries = {"environment": "local"}
    missing = []

    for name, key in REQUIRED.items():
        value = env(name)
        if value:
            entries[key] = value
        else:
            missing.append(name)

    for name, key in {**RECOMMENDED, **OPTIONAL}.items():
        value = env(name)
        if value:
            entries[key] = value

    entries.update(database_entries())

    if missing:
        print("⚠️  Missing Codespaces secrets: " + ", ".join(missing))
        print("   Add them under the repository Settings → Secrets and variables")
        print("   → Codespaces, then run: bash .devcontainer/start.sh")

    lines = ["# Generated from environment variables — do not commit.", ""]
    lines += [f'{key} = "{toml_escape(value)}"' for key, value in sorted(entries.items())]

    SECRETS_PATH.parent.mkdir(parents=True, exist_ok=True)
    SECRETS_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.chmod(SECRETS_PATH, stat.S_IRUSR | stat.S_IWUSR)

    print(f"✓ wrote {SECRETS_PATH} with keys: {', '.join(sorted(entries))}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
