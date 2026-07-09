#!/usr/bin/env node

// Reverse of symlinks.js: removes only the symlinks that point back into this repo,
// then uninstalls the dotfiles autosync launchd agent. Real files/dirs are never touched.

import fs from 'fs';
import path from 'path';
import os from 'os';
import { execFileSync } from 'child_process';
import chalk from 'chalk';

const repoRoot = new URL('..', import.meta.url).pathname;
const dotfilesDir = path.join(repoRoot, 'symlinks');
const homeDir = os.homedir();
const repoReal = fs.realpathSync(repoRoot);

const MERGE_PARENTS = ['.claude/skills'];
const underMergeParent = (rel) =>
	MERGE_PARENTS.some((p) => rel === p || rel.startsWith(p + path.sep));

console.log(chalk.blue.bold('\n🧹 Removing dotfile symlinks...\n'));

function unlink(relativePath) {
	const targetPath = path.join(homeDir, relativePath);

	let stat;
	try {
		stat = fs.lstatSync(targetPath);
	} catch {
		return; // nothing there
	}

	if (!stat.isSymbolicLink()) {
		console.log(chalk.gray(`•  Skipped (not a symlink): ${relativePath}`));
		return;
	}

	// Only remove symlinks that point back into this repo.
	const dest = path.resolve(path.dirname(targetPath), fs.readlinkSync(targetPath));
	if (!dest.startsWith(repoReal)) {
		console.log(chalk.gray(`•  Skipped (points elsewhere): ${relativePath}`));
		return;
	}

	fs.unlinkSync(targetPath);
	console.log(chalk.yellow(`✗  Removed symlink: ${relativePath}`));
}

// 1) Merge-parent children.
for (const parentRel of MERGE_PARENTS) {
	const parentSrc = path.join(dotfilesDir, parentRel);
	if (!fs.existsSync(parentSrc)) continue;
	for (const child of fs.readdirSync(parentSrc)) {
		unlink(path.join(parentRel, child));
	}
}

// 2) Individual files.
const entries = fs.readdirSync(dotfilesDir, {
	recursive: true,
	withFileTypes: true,
});

for (const entry of entries) {
	if (entry.isDirectory()) continue;

	const relativePath = path.relative(
		dotfilesDir,
		path.join(entry.parentPath, entry.name),
	);
	if (underMergeParent(relativePath)) continue;

	unlink(relativePath);
}

console.log(chalk.blue.bold('\n✨ Symlinks removed!\n'));

// 3) Uninstall the autosync launchd agent (macOS only).
if (process.platform === 'darwin') {
	try {
		console.log(chalk.blue.bold('⏱  Uninstalling dotfiles autosync agent...\n'));
		execFileSync('bash', [path.join(repoRoot, 'scripts', 'uninstall-autosync.sh')], {
			stdio: 'inherit',
		});
	} catch (err) {
		console.log(chalk.red(`⚠  Autosync uninstall failed: ${err.message}`));
	}
}
