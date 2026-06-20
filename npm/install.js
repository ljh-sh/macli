#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const pkg = require('./package.json');
const version = pkg.version;

if (version === '0.0.0') {
  console.log('Skipping binary download for development placeholder version.');
  process.exit(0);
}

if (process.platform !== 'darwin') {
  console.log('macli is only available on macOS; skipping binary download.');
  process.exit(0);
}

const binDir = path.join(__dirname, 'bin');
const binaryPath = path.join(binDir, 'macli-binary');
const tarPath = path.join(__dirname, `macli-darwin-universal.tar.xz`);
const url = `https://github.com/ljh-sh/macli/releases/download/v${version}/macli-darwin-universal.tar.xz`;

fs.mkdirSync(binDir, { recursive: true });

console.log(`Downloading macli v${version} for macOS...`);
try {
  execFileSync('curl', ['-fsSL', '-o', tarPath, url], { stdio: 'inherit' });
} catch (err) {
  console.error(`Failed to download macli from ${url}`);
  process.exit(1);
}

const tmpDir = fs.mkdtempSync(path.join(__dirname, 'tmp-'));
try {
  execFileSync('tar', ['xJf', tarPath, '-C', tmpDir], { stdio: 'inherit' });
  const extracted = path.join(tmpDir, 'bin', 'macli');
  if (!fs.existsSync(extracted)) {
    console.error('macli binary not found in downloaded tarball');
    process.exit(1);
  }
  fs.renameSync(extracted, binaryPath);
  fs.chmodSync(binaryPath, 0o755);
} finally {
  fs.rmSync(tmpDir, { recursive: true, force: true });
  fs.rmSync(tarPath, { force: true });
}

console.log('macli installed successfully.');
