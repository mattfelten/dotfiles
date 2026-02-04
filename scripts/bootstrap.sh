#!/usr/bin/env bash
set -e

# Repo root (parent of scripts/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh"

need_npm_install_and_start() {
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

# NVM installed: source it and ensure Node is installed
if [ -f "$NVM_DIR/nvm.sh" ]; then
	echo "NVM found, loading and ensuring Node is installed..."
	# shellcheck source=/dev/null
	source "$NVM_DIR/nvm.sh"
	if [ -f "$REPO_ROOT/.nvmrc" ]; then
		nvm install
	else
		nvm install --default --latest-npm
	fi
	echo "Running npm install and npm start..."
	need_npm_install_and_start
	exit 0
fi

# No NVM: install it, then Node, then npm install + npm start
echo "Installing NVM..."
export NVM_DIR
curl -o- "$NVM_INSTALL_URL" | bash

# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"

echo "Installing Node..."
if [ -f "$REPO_ROOT/.nvmrc" ]; then
	nvm install
else
	nvm install --default --latest-npm
fi

echo "Running npm install and npm start..."
need_npm_install_and_start
