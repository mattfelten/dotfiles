#!/usr/bin/env node

import { execSync, spawnSync } from 'child_process';
import path from 'path';
import fs from 'fs';
import os from 'os';
import chalk from 'chalk';
import checkbox, { Separator } from '@inquirer/checkbox';

const brewfilePath = path.join(process.cwd(), 'homebrew/Brewfile');
const isMac = process.platform === 'darwin';
const installAll = process.argv.includes('--all');

// Where the Homebrew installer puts brew (Apple Silicon, Intel, Linux)
const brewLocations = [
	'/opt/homebrew/bin/brew',
	'/usr/local/bin/brew',
	'/home/linuxbrew/.linuxbrew/bin/brew',
];

console.log(chalk.blue.bold('\n🍺 Setting up Homebrew...\n'));

if (!fs.existsSync(brewfilePath)) {
	console.log(chalk.red(`✗  Brewfile not found at ${brewfilePath}`));
	process.exit(1);
}

// The installer doesn't touch PATH, so a fresh install isn't findable as
// `brew` in this process. Find it by location and load its environment.
function loadBrew() {
	const brew = brewLocations.find((p) => fs.existsSync(p));
	if (!brew) return false;
	const env = execSync(`${brew} shellenv`, { encoding: 'utf8' });
	for (const [, key, value] of env.matchAll(/export (\w+)="([^"]*)"/g)) {
		process.env[key] = value.replace(/\$\{?(\w+)\}?/g, (_, v) => process.env[v] ?? '');
	}
	return true;
}

if (loadBrew()) {
	console.log(chalk.green('✓  Homebrew found'));
} else {
	console.log(chalk.yellow('↻  Installing Homebrew...'));
	try {
		execSync(
			'/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
			{ stdio: 'inherit' },
		);
	} catch {
		console.log(chalk.red('✗  Failed to install Homebrew'));
		process.exit(1);
	}
	if (!loadBrew()) {
		console.log(chalk.red('✗  Homebrew installed but brew not found in any of:'));
		brewLocations.forEach((p) => console.log(chalk.red(`   ${p}`)));
		process.exit(1);
	}
	console.log(chalk.green('✓  Homebrew installed'));
}

// Each Brewfile entry becomes a choice, grouped under the `## Heading` above
// it. Taps always install.
let group = '';
const entries = [];
for (const raw of fs.readFileSync(brewfilePath, 'utf8').split('\n')) {
	const line = raw.trim();
	if (line.startsWith('## ')) {
		group = line.slice(3);
		continue;
	}
	if (!/^(tap|brew|cask|mas)\s/.test(line)) continue;
	const [, type, name] = line.match(/^(\w+)\s+["']([^"']+)["']/);
	if (!isMac && (type === 'cask' || type === 'mas')) continue;
	const hint = line.match(/#\s*(.+)$/)?.[1];
	entries.push({ type, name, hint, group, line: line.replace(/\s*#.*$/, '') });
}

const taps = entries.filter((e) => e.type === 'tap');
const options = entries.filter((e) => e.type !== 'tap');

let selected = options;
if (!installAll && process.stdin.isTTY) {
	const choices = [];
	options.forEach((e, i) => {
		if (e.group && e.group !== options[i - 1]?.group) {
			choices.push(new Separator(chalk.bold(`\n ${e.group}`)));
		}
		choices.push({
			name: `${e.name} ${chalk.dim(e.type + (e.hint ? ` · ${e.hint}` : ''))}`,
			value: e,
			checked: true,
		});
	});
	selected = await checkbox({
		message: 'What should this machine get?',
		pageSize: 30,
		loop: false,
		choices,
	});
} else {
	console.log(chalk.gray('Non-interactive, installing everything in the Brewfile'));
}

if (selected.length === 0) {
	console.log(chalk.yellow('Nothing selected, skipping brew bundle'));
	process.exit(0);
}

const lines = [...taps, ...selected].map((e) => e.line);
if (selected.some((e) => e.type === 'mas')) lines.unshift("brew 'mas'");

const tmpBrewfile = path.join(os.tmpdir(), `Brewfile.${process.pid}`);
fs.writeFileSync(tmpBrewfile, lines.join('\n') + '\n');

console.log(chalk.gray(`\nRunning brew bundle with ${selected.length} items...`));
const result = spawnSync('brew', ['bundle', '--file', tmpBrewfile], {
	stdio: 'inherit',
});
fs.rmSync(tmpBrewfile, { force: true });

// brew bundle keeps going past a failed item, so a nonzero exit usually means
// one or two things didn't install. Don't let that block the rest of setup.
if (result.error) {
	console.log(chalk.red(`\n✗  Couldn't run brew bundle: ${result.error.message}`));
	process.exit(1);
}
if (result.status !== 0) {
	console.log(chalk.yellow('\n⚠  Some items failed to install, see above. Re-run `npm run homebrew` to retry.'));
} else {
	console.log(chalk.blue.bold('\n✨ Done!\n'));
}
