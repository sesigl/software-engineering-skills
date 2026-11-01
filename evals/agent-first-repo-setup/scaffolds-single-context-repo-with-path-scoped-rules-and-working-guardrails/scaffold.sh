#!/usr/bin/env bash
# Prepares a Python virtual environment, because the eval sandbox has no network access.
# The sandbox blocks interpreters under the user's home (for example pyenv), so the script uses a Homebrew Python.
# Set EVAL_PYTHON to override.
set -euo pipefail
PY="${EVAL_PYTHON:-}"
if [ -z "$PY" ]; then
  for c in /opt/homebrew/bin/python3.13 /opt/homebrew/bin/python3.12 /usr/local/bin/python3.13 /usr/local/bin/python3.12; do
    if [ -x "$c" ]; then PY="$c"; break; fi
  done
fi
[ -n "$PY" ] || { echo "No Homebrew Python 3.12 or 3.13 found. Set EVAL_PYTHON." >&2; exit 1; }
"$PY" -m venv .venv
.venv/bin/pip install -q --disable-pip-version-check fastapi httpx pytest pytest-cov coverage mutmut radon
