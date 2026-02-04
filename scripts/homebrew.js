#!/usr/bin/env node

const { execSync, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const chalk = require('chalk');

const brewfilePath = path.join(process.cwd(), 'homebrew/Brewfile');
const brewfileMacosPath = path.join(process.cwd(), 'homebrew/Brewfile.macos');

console.log(chalk.blue.bold('\n🍺 Setting up Homebrew...\n'));

if (!fs.existsSync(brewfilePath)) {
	console.log(
		chalk.red(`✗  Brewfile not found at ${brewfilePath}`),
	);
	process.exit(1);
}

// Check if Homebrew is installed
try {
	execSync('command -v brew', { stdio: 'ignore' });
	console.log(chalk.green('✓  Homebrew found'));
} catch {
	console.log(chalk.yellow('↻  Installing Homebrew...'));
	try {
		execSync(
			'/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
			{ stdio: 'inherit' },
		);
		console.log(chalk.green('✓  Homebrew installed'));
	} catch {
		console.log(chalk.red('✗  Failed to install Homebrew'));
		process.exit(1);
	}
}

console.log(chalk.gray('Running brew bundle...'));
let result = spawnSync('brew', ['bundle', '--file', brewfilePath], {
	stdio: 'inherit',
});

if (result.error || result.status !== 0) {
	console.log(chalk.red('\n✗  brew bundle failed'));
	process.exit(result.status || 1);
}

if (process.platform === 'darwin' && fs.existsSync(brewfileMacosPath)) {
	console.log(chalk.gray('Running brew bundle (macOS)...'));
	result = spawnSync('brew', ['bundle', '--file', brewfileMacosPath], {
		stdio: 'inherit',
	});
	if (result.error || result.status !== 0) {
		console.log(chalk.red('\n✗  brew bundle (macOS) failed'));
		process.exit(result.status || 1);
	}
}

console.log(chalk.blue.bold('\n✨ Done!\n'));
