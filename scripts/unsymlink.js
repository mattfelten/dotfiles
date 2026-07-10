#!/usr/bin/env node

// Reverse of symlinks.js: removes only the symlinks that point back into this repo.
// Real files/dirs are never touched. (The autosync agent is handled separately —
// see `npm run autosync:uninstall` / `npm run unlink`.)

import fs from 'fs';
import path from 'path';
import os from 'os';
import chalk from 'chalk';

const dotfilesDir = new URL('../symlinks', import.meta.url).pathname;
const homeDir = os.homedir();
const repoReal = fs.realpathSync(new URL('..', import.meta.url).pathname);

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
