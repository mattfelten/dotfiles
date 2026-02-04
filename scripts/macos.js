#!/usr/bin/env node

const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const chalk = require('chalk');

const macosDefaultsDir = path.join(__dirname, '..', 'macos-defaults');

console.log(chalk.blue.bold('\n🍎 Configuring macOS defaults...\n'));

// Request sudo upfront (inherit stdio so user can type password)
console.log(chalk.gray('Requesting administrator privileges...'));
spawnSync('sudo', ['-v'], { stdio: 'inherit' });

// Start sudo keep-alive in background
const keepAlive = setInterval(() => {
	execSync('sudo -n true', { stdio: 'ignore' });
}, 30000);

// Close System Preferences
console.log(chalk.gray('Closing System Preferences...\n'));
execSync(
	'osascript -e \'tell application "System Preferences" to quit\'',
	{ stdio: 'ignore' },
);

// Execute each script in macos-defaults/
const scripts = fs
	.readdirSync(macosDefaultsDir)
	.filter((f) => f.endsWith('.sh'))
	.sort();

const SAFARI_FDA_MESSAGE =
	'Safari preferences are in a protected container. Grant Full Disk Access to this terminal/app in\n' +
	'  System Settings → Privacy & Security → Full Disk Access\n' +
	'then run this script again.';

for (const script of scripts) {
	const scriptPath = path.join(macosDefaultsDir, script);
	const name = path.basename(script, '.sh');
	const isSafari = name === 'safari';

	if (isSafari) {
		// Safari prefs require Full Disk Access; check before running to show a clear message
		try {
			execSync(
				'defaults write com.apple.Safari HomePage -string "http://calendar.google.com"',
				{ stdio: 'pipe' },
			);
		} catch {
			console.log(chalk.yellow(`⊘  ${name}`));
			console.log(chalk.yellow(SAFARI_FDA_MESSAGE));
			continue;
		}
	}

	try {
		execSync(`bash "${scriptPath}"`, {
			stdio: isSafari ? 'pipe' : 'inherit',
		});
		console.log(chalk.green(`✓  ${name}`));
	} catch (err) {
		console.log(chalk.red(`✗  ${name}: ${err.message}`));
	}
}

clearInterval(keepAlive);
console.log(
	chalk.blue.bold(
		'\n✨ Done. Some changes may require logout/restart.\n',
	),
);
