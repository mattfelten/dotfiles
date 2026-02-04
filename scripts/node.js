#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const chalk = require('chalk');

const nvmDir = process.env.NVM_DIR || path.join(os.homedir(), '.nvm');

console.log(chalk.blue.bold('\n📦 Setting up Node with nvm...\n'));

// Check if nvm is installed
if (!fs.existsSync(path.join(nvmDir, 'nvm.sh'))) {
	console.log(chalk.yellow('↻  Installing nvm...'));
	try {
		execSync(
			'/bin/bash -c "$(curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh)"',
			{ stdio: 'inherit' },
		);
		console.log(chalk.green('✓  nvm installed'));
	} catch {
		console.log(chalk.red('✗  Failed to install nvm'));
		process.exit(1);
	}
} else {
	console.log(chalk.green('✓  nvm found'));
}

console.log(chalk.gray('Installing Node...'));
try {
	execSync(
		`bash -c "source ${nvmDir}/nvm.sh && nvm install --default --latest-npm"`,
		{ stdio: 'inherit' },
	);
	console.log(chalk.green('✓  Node installed'));
} catch {
	console.log(chalk.red('✗  Failed to install Node'));
	process.exit(1);
}

console.log(chalk.blue.bold('\n✨ Done!\n'));
