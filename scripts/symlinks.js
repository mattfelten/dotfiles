#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');
const chalk = require('chalk');

const dotfilesDir = path.join(__dirname, '..', 'symlinks');
const homeDir = os.homedir();

console.log(chalk.blue.bold('\n📁 Setting up dotfile symlinks...\n'));

const entries = fs.readdirSync(dotfilesDir, {
	recursive: true,
	withFileTypes: true,
});

for (const entry of entries) {
	if (entry.isDirectory()) continue;

	const sourcePath = path.join(entry.parentPath, entry.name);
	const relativePath = path.relative(dotfilesDir, sourcePath);
	const targetPath = path.join(homeDir, relativePath);
	const targetDir = path.dirname(targetPath);

	// Ensure parent directory exists
	if (!fs.existsSync(targetDir)) {
		fs.mkdirSync(targetDir, { recursive: true });
		console.log(
			chalk.blue(
				`📂 Created directory: ${path.relative(homeDir, targetDir)}`,
			),
		);
	}

	// Check if target already exists (use lstat to detect broken symlinks too)
	let targetExists = false;
	let isSymlink = false;
	try {
		isSymlink = fs.lstatSync(targetPath).isSymbolicLink();
		targetExists = true;
	} catch {}

	if (targetExists) {
		if (isSymlink) {
			fs.unlinkSync(targetPath);
			fs.symlinkSync(sourcePath, targetPath);
			console.log(
				chalk.yellow(`↻  Replaced symlink: ${relativePath}`),
			);
		} else {
			console.log(
				chalk.red(
					`⚠  Skipped (file exists): ${relativePath}`,
				),
			);
		}
	} else {
		fs.symlinkSync(sourcePath, targetPath);
		console.log(
			chalk.green(`✓  Created symlink: ${relativePath}`),
		);
	}
}

console.log(chalk.blue.bold('\n✨ Done!\n'));
