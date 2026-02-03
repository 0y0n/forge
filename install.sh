#!/usr/bin/env bash
# ==============================================================================
# Forge — Bootstrap installer for remote-workstation
# 
# SECURITY: Never pipe scripts directly to sudo bash from the internet.
# 
# Recommended installation procedure:
#   1. curl -fsSL https://raw.githubusercontent.com/0y0n/forge/main/install.sh -o install.sh
#   2. less install.sh        # Review the script content
#   3. chmod +x install.sh
#   4. sudo ./install.sh
# ==============================================================================
set -euo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[FORGE]${NC} $*"; }
warn()  { echo -e "${YELLOW}[FORGE WARN]${NC} $*"; }
abort() { echo -e "${RED}[FORGE ABORT]${NC} $*" >&2; exit 1; }

# ── constants ────────────────────────────────────────────────────────────────
REPO_URL="https://github.com/0y0n/forge.git"
REPO_DIR="${HOME}/forge"
EXPECTED_OS_ID="ubuntu"
EXPECTED_VERSION_ID="24.04"

# ── 1. OS guard ──────────────────────────────────────────────────────────────
info "Checking OS …"
[[ -f /etc/os-release ]] || abort "/etc/os-release not found"
# shellcheck source=/dev/null
source /etc/os-release
[[ "${ID:-}" == "$EXPECTED_OS_ID" ]]             || abort "Expected Ubuntu, got '${ID:-unknown}'"
[[ "${VERSION_ID:-}" == "$EXPECTED_VERSION_ID" ]] || abort "Expected ${EXPECTED_VERSION_ID}, got '${VERSION_ID:-unknown}'"
# Ensure we are NOT running a desktop flavour (gnome-shell / xfce4-session absent at this stage is fine)
if dpkg -s ubuntu-desktop >/dev/null 2>&1; then
  abort "This installer targets Ubuntu Server, not a desktop edition."
fi
info "OS check passed  →  Ubuntu Server ${VERSION_ID}"

# ── 2. Privilege check ───────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  abort "This script must be run as root.

Please follow the secure installation procedure:

  1. curl -fsSL https://raw.githubusercontent.com/0y0n/forge/main/install.sh -o install.sh
  2. less install.sh        # Review the script content
  3. chmod +x install.sh
  4. sudo ./install.sh

Never pipe internet scripts directly to sudo bash."
fi

# ── 3. Update & upgrade ─────────────────────────────────────────────────────
info "Updating package index …"
apt-get update -qq
info "Upgrading installed packages …"
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# ── 4. Install git ──────────────────────────────────────────────────────────
info "Ensuring git is installed …"
apt-get install -y -qq git

# ── 5. Clone Forge repository ────────────────────────────────────────────────
if [[ -d "$REPO_DIR/.git" ]]; then
  info "Repo already exists at ${REPO_DIR}, pulling latest …"
  git -C "$REPO_DIR" pull --ff-only
else
  info "Cloning repo → ${REPO_DIR}"
  git clone --depth 1 "$REPO_URL" "$REPO_DIR"
fi

# ── 6. Install Ansible ──────────────────────────────────────────────────────
info "Installing Ansible …"
if ! command -v ansible-playbook &>/dev/null; then
  # Use pipx for an isolated, stable ansible install (no PPA race conditions)
  apt-get install -y -qq pipx python3-pip
  pipx ensurepath
  # shellcheck source=/dev/null
  [[ -f "${HOME}/.local/bin/pipx" ]] && export PATH="${HOME}/.local/bin:${PATH}"
  pipx install ansible
  # Make it available system-wide for root
  ANSIBLE_BIN=$(pipx show ansible 2>/dev/null | grep Location | awk '{print $2}')
  ln -sf "${ANSIBLE_BIN}/bin/ansible-playbook" /usr/local/bin/ansible-playbook
  ln -sf "${ANSIBLE_BIN}/bin/ansible"          /usr/local/bin/ansible
fi
ansible --version | head -1

# ── 7. Launch the playbook ──────────────────────────────────────────────────
info "Starting Ansible playbook for remote-workstation …"
cd "$REPO_DIR"

ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/remote_workstation.yml \
  --connection local \
  -e "ansible_become=yes" \
  -v

info "═══════════════════════════════════════════════════"
info " Forge bootstrap for remote-workstation complete.  "
info "═══════════════════════════════════════════════════"