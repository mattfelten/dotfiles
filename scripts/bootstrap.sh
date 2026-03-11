#!/usr/bin/env bash
set -euo pipefail

trap 'echo "Bootstrap failed at line $LINENO (exit code $?). Check the output above for details." >&2' ERR

# Repo root (parent of scripts/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh"

need_npm_install_and_start() {
	command -v node &>/dev/null || { echo "ERROR: node not found — nvm install may have failed" >&2; exit 1; }
	cd "$REPO_ROOT"
	npm install
	npm start
}

# Node already available (e.g. from Homebrew or existing NVM in this shell)
if command -v node &>/dev/null; then
	echo "Node found, running npm install and npm start..."
	need_npm_install_and_start
	exit 0
fi

load_nvm() {
	# nvm is a shell function that uses non-zero exits internally — disable set -e around it
	set +eu
	# shellcheck source=/dev/null
	source "$NVM_DIR/nvm.sh"
	set -eu
	command -v nvm &>/dev/null || { echo "ERROR: nvm not available after sourcing $NVM_DIR/nvm.sh" >&2; exit 1; }
}

install_node() {
	local version
	version="$(cat "$REPO_ROOT/.nvmrc" 2>/dev/null || echo "--lts")"
	set +eu
	nvm install "$version"
	nvm_exit=$?
	set -eu
	if [ $nvm_exit -ne 0 ]; then
		echo "ERROR: nvm install $version failed (exit $nvm_exit)" >&2
		exit 1
	fi
}

# NVM installed: source it and ensure Node is installed
if [ -f "$NVM_DIR/nvm.sh" ]; then
	echo "NVM found, loading and ensuring Node is installed..."
	load_nvm
	install_node
	echo "Running npm install and npm start..."
	need_npm_install_and_start
	exit 0
fi

# No NVM: install it, then Node, then npm install + npm start
echo "Installing NVM..."
export NVM_DIR
curl --fail -o- "$NVM_INSTALL_URL" | bash

load_nvm

echo "Installing Node..."
install_node

echo "Running npm install and npm start..."
need_npm_install_and_start
