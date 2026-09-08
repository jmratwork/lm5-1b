#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[run_playbook] Required command '$cmd' not found" >&2
    exit 1
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAYBOOK="$SCRIPT_DIR/playbook.yml"
COLLECTIONS_FILE="$SCRIPT_DIR/collections.yml"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.yml"

# Use the ansible.cfg next to the playbook regardless of the caller's cwd.
export ANSIBLE_CONFIG="$SCRIPT_DIR/ansible.cfg"

require_cmd ansible-galaxy
require_cmd ansible-playbook
require_cmd wget
require_cmd virtualbmc

# The password_hash filter runs on the control node and needs passlib; without it
# Ansible falls back to the deprecated crypt module (removed in ansible-core 2.17).
if ! python3 -c 'import passlib' >/dev/null 2>&1; then
  echo "[run_playbook] Installing passlib (required by the password_hash filter)." >&2
  python3 -m pip install --quiet passlib \
    || pip3 install --quiet passlib \
    || echo "[run_playbook] WARNING: could not install passlib; password_hash will use the deprecated crypt module." >&2
fi

echo "[run_playbook] Installing required collections and roles, then running provisioning/playbook.yml." >&2
echo "[run_playbook] Use this wrapper instead of calling ansible-playbook directly on KYPO/CRCZ to avoid missing modules." >&2

if [[ $# -gt 0 ]]; then
  INVENTORY="$1"
  shift
else
  INVENTORY="$REPO_ROOT/inventory.ini"
fi

if [[ ! -f "$COLLECTIONS_FILE" ]]; then
  echo "[run_playbook] Collections file '$COLLECTIONS_FILE' not found" >&2
  exit 1
fi

if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
  echo "[run_playbook] Requirements file '$REQUIREMENTS_FILE' not found" >&2
  exit 1
fi

if [[ ! -f "$PLAYBOOK" ]]; then
  echo "[run_playbook] Playbook '$PLAYBOOK' not found" >&2
  exit 1
fi

if [[ ! -f "$INVENTORY" ]]; then
  echo "[run_playbook] Inventory file '$INVENTORY' not found" >&2
  exit 1
fi

ansible-galaxy collection install -r "$COLLECTIONS_FILE"
ansible-galaxy role install -r "$REQUIREMENTS_FILE"
ansible-playbook -i "$INVENTORY" "$PLAYBOOK" "$@"
