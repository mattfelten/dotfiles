#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import os from 'os';
import { execFileSync } from 'child_process';
import chalk from 'chalk';

const repoRoot = new URL('..', import.meta.url).pathname;
const dotfilesDir = path.join(repoRoot, 'symlinks');
const homeDir = os.homedir();

// Directories whose *immediate children* are each symlinked as a whole unit (dir or
// file), while the parent stays a real directory in $HOME. This lets our synced entries
// coexist with entries other tools manage in the same directory — e.g. ~/.claude/skills
// also holds marketplace-managed skill symlinks that must NOT be synced.
const MERGE_PARENTS = ['.claude/skills'];

const underMergeParent = (rel) =>
	MERGE_PARENTS.some((p) => rel === p || rel.startsWith(p + path.sep));

console.log(chalk.blue.bold('\n📁 Setting up dotfile symlinks...\n'));

function link(sourcePath, relativePath) {
	const targetPath = path.join(homeDir, relativePath);
	const targetDir = path.dirname(targetPath);

	if (!fs.existsSync(targetDir)) {
		fs.mkdirSync(targetDir, { recursive: true });
		console.log(
			chalk.blue(`📂 Created directory: ${path.relative(homeDir, targetDir)}`),
		);
	}

	let stat;
	try {
		stat = fs.lstatSync(targetPath);
	} catch {}

	if (stat) {
		if (stat.isSymbolicLink()) {
			fs.unlinkSync(targetPath);
			fs.symlinkSync(sourcePath, targetPath);
			console.log(chalk.yellow(`↻  Replaced symlink: ${relativePath}`));
		} else {
			console.log(
				chalk.red(
					`⚠  Skipped (real file/dir exists — remove it to symlink): ${relativePath}`,
				),
			);
		}
		return;
	}

	fs.symlinkSync(sourcePath, targetPath);
	console.log(chalk.green(`✓  Created symlink: ${relativePath}`));
}

// 1) Merge parents: symlink each immediate child as a whole unit, keeping the parent real.
for (const parentRel of MERGE_PARENTS) {
	const parentSrc = path.join(dotfilesDir, parentRel);
	if (!fs.existsSync(parentSrc)) continue;

	const parentTarget = path.join(homeDir, parentRel);
	if (!fs.existsSync(parentTarget)) {
		fs.mkdirSync(parentTarget, { recursive: true });
		console.log(
			chalk.blue(`📂 Created directory: ${path.relative(homeDir, parentTarget)}`),
		);
	}

	for (const child of fs.readdirSync(parentSrc)) {
		link(path.join(parentSrc, child), path.join(parentRel, child));
	}
}

// 2) Everything else: symlink individual files (skipping merge-parent subtrees).
const entries = fs.readdirSync(dotfilesDir, {
	recursive: true,
	withFileTypes: true,
});

for (const entry of entries) {
	if (entry.isDirectory()) continue;

	const sourcePath = path.join(entry.parentPath, entry.name);
	const relativePath = path.relative(dotfilesDir, sourcePath);
	if (underMergeParent(relativePath)) continue;

	link(sourcePath, relativePath);
}

console.log(chalk.blue.bold('\n✨ Symlinks done!\n'));

// 3) Install the launchd agent that keeps this repo git-synced (macOS only).
// Set DOTFILES_NO_AUTOSYNC=1 to skip (CI, testing, or a machine you don't want syncing).
if (process.env.DOTFILES_NO_AUTOSYNC) {
	console.log(chalk.gray('Skipping autosync agent (DOTFILES_NO_AUTOSYNC set).'));
} else if (process.platform === 'darwin') {
	try {
		console.log(chalk.blue.bold('⏱  Installing dotfiles autosync agent...\n'));
		execFileSync('bash', [path.join(repoRoot, 'scripts', 'install-autosync.sh')], {
			stdio: 'inherit',
		});
	} catch (err) {
		console.log(chalk.red(`⚠  Autosync install failed: ${err.message}`));
	}
} else {
	console.log(chalk.gray('Skipping autosync agent (macOS only).'));
}
