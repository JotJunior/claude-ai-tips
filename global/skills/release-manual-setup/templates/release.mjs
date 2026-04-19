#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT           = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const PKG_PATH       = resolve(ROOT, 'package.json');
const CHANGELOG_PATH = resolve(ROOT, 'CHANGELOG.md');

const BODY_REQUIRED_TYPES = new Set(['feat', 'fix']);
const MIN_BODY_LENGTH     = 20;
const PRE_1_0_MAJOR_AS_MINOR = true;
const RUN_TESTS_BEFORE    = true;
const AUTO_PUSH           = false;
const TAG_PREFIX          = 'v';
const COMMIT_SEP          = '---COMMIT-END---';

const DRY_RUN  = process.env.DRY_RUN  === '1';
const NO_TESTS = process.env.NO_TESTS === '1';
const NO_PUSH  = process.env.NO_PUSH  === '1';
const FORCED_BUMP = process.env.BUMP;

export {
  parseCommit,
  detectBumpType,
  checkQuality,
  formatEntry,
  groupCommits,
  buildEntry,
  bump,
};

// ---------------------------------------------------------------------------
// Git helpers
// ---------------------------------------------------------------------------

function git(args, opts = {}) {
  const result = spawnSync('git', args, { cwd: ROOT, encoding: 'utf8', ...opts });
  if (result.status !== 0) throw new Error(`git ${args.join(' ')} failed:\n${result.stderr}`);
  return result.stdout.trim();
}

function latestTag() {
  try {
    return git(['describe', '--tags', '--abbrev=0']);
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Commit parsing
// ---------------------------------------------------------------------------

function readCommits(logRange) {
  const format = `--format=%H%n%s%n%b%n${COMMIT_SEP}`;
  const raw = git(['log', logRange, format, '--no-merges']);

  return raw
    .split(COMMIT_SEP)
    .map((block) => block.trim())
    .filter(Boolean)
    .map((block) => {
      const lines   = block.split('\n');
      const hash    = lines[0].trim();
      const subject = lines[1]?.trim() ?? '';
      const body    = lines.slice(2).join('\n').trim();
      return { hash, subject, body };
    })
    .filter((c) => c.hash && c.subject);
}

function parseCommit({ hash, subject, body }) {
  const match = subject.match(/^([a-z]+)(\(([^)]+)\))?(!)?: (.+)$/);
  if (!match) {
    return { hash, type: null, scope: null, breaking: false, description: subject, body };
  }

  const [, type, , scope, bang, description] = match;
  const breaking = bang === '!' || /BREAKING[- ]CHANGE/i.test(body);

  return { hash, type, scope: scope ?? null, breaking, description, body };
}

// ---------------------------------------------------------------------------
// Quality enforcement
// ---------------------------------------------------------------------------

function checkQuality(commits) {
  return commits.filter((c) => {
    if (!c.type) return false;
    if (c.breaking) return !c.body || c.body.length < MIN_BODY_LENGTH;
    return BODY_REQUIRED_TYPES.has(c.type) && (!c.body || c.body.length < MIN_BODY_LENGTH);
  });
}

function failQuality(failing) {
  const lines = ['', 'Quality check failed — these commits need a body before releasing:\n'];

  for (const c of failing) {
    const reason = c.breaking
      ? 'breaking changes require a body description'
      : `${c.type} commits require a body description`;
    const header = `${c.type}${c.scope ? `(${c.scope})` : ''}${c.breaking ? '!' : ''}`;
    lines.push(`  ${c.hash.slice(0, 7)}  ${header}: ${c.description}`);
    lines.push(`           \u2191 ${reason} (>= ${MIN_BODY_LENGTH} chars)\n`);
  }

  lines.push('How to fix:');
  lines.push('  git commit --amend          amend the last commit');
  lines.push('  git rebase -i <hash>^       edit an older commit body');
  lines.push('');

  throw new Error(lines.join('\n'));
}

// ---------------------------------------------------------------------------
// Version helpers
// ---------------------------------------------------------------------------

function parseVersion(tag) {
  const m = tag.replace(new RegExp(`^${TAG_PREFIX}`), '').match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!m) throw new Error(`Cannot parse version: ${tag}`);
  return { major: Number(m[1]), minor: Number(m[2]), patch: Number(m[3]) };
}

function formatVersion({ major, minor, patch }) {
  return `${major}.${minor}.${patch}`;
}

function bump(version, type) {
  const pre = version.major === 0;
  if (type === 'major') return pre && PRE_1_0_MAJOR_AS_MINOR
    ? { major: 0, minor: version.minor + 1, patch: 0 }
    : { major: version.major + 1, minor: 0, patch: 0 };
  if (type === 'minor') return { major: version.major, minor: version.minor + 1, patch: 0 };
  return { major: version.major, minor: version.minor, patch: version.patch + 1 };
}

function detectBumpType(commits) {
  let hasBreaking = false;
  let hasFeat    = false;

  for (const c of commits) {
    if (c.breaking) hasBreaking = true;
    if (c.type === 'feat') hasFeat = true;
  }

  if (hasBreaking) return 'major';
  if (hasFeat)    return 'minor';
  return 'patch';
}

// ---------------------------------------------------------------------------
// Changelog formatting
// ---------------------------------------------------------------------------

function formatEntry(commit) {
  const title = `**${commit.description}**`;
  if (!commit.body) return `- ${title}`;

  const bodyText = commit.body
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean)
    .join(' ');

  return `- ${title} \u2014 ${bodyText}`;
}

function groupCommits(commits) {
  const groups = { breaking: [], feat: [], fix: [], chore: [] };

  for (const c of commits) {
    const entry = formatEntry(c);
    if (c.breaking)                                        { groups.breaking.push(entry); continue; }
    if (c.type === 'feat')                                 { groups.feat.push(entry); continue; }
    if (c.type === 'fix')                                  { groups.fix.push(entry); continue; }
    if (c.type && c.type !== 'feat' && c.type !== 'fix')   { groups.chore.push(entry); continue; }
  }

  return groups;
}

function buildEntry(version, groups) {
  const date  = new Date().toISOString().slice(0, 10);
  const lines = [`## [${version}] - ${date}`, ''];

  const sections = [
    ['### Breaking Changes', groups.breaking],
    ['### Added',            groups.feat],
    ['### Fixed',            groups.fix],
    ['### Changed',          groups.chore],
  ];

  for (const [heading, items] of sections) {
    if (items.length === 0) continue;
    lines.push(heading, '');
    for (const item of items) lines.push(item);
    lines.push('');
  }

  return lines.join('\n');
}

function updateChangelog(version, groups) {
  const entry = buildEntry(version, groups);
  let existing;
  try {
    existing = readFileSync(CHANGELOG_PATH, 'utf8');
  } catch {
    existing = '# Changelog\n\nAll notable changes to this project will be documented in this file.\n\nThe format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),\nand this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n\n## [Unreleased]\n\n';
  }

  const unreleasedMatch = existing.match(/^## \[Unreleased\]/m);
  const newContent = unreleasedMatch
    ? existing.replace(/^## \[Unreleased\]\s*\n/m, `## [Unreleased]\n\n${entry}\n`)
    : existing + '\n' + entry + '\n';

  if (!DRY_RUN) writeFileSync(CHANGELOG_PATH, newContent);
  return entry;
}

// ---------------------------------------------------------------------------
// Release orchestration
// ---------------------------------------------------------------------------

function loadPackageJson() {
  return JSON.parse(readFileSync(PKG_PATH, 'utf8'));
}

function updatePackageVersion(version) {
  const pkg = loadPackageJson();
  pkg.version = version;
  if (!DRY_RUN) writeFileSync(PKG_PATH, JSON.stringify(pkg, null, 2) + '\n');
}

function ensureCleanWorkingTree() {
  const status = git(['status', '--porcelain']);
  if (status.length > 0) {
    throw new Error('Working tree not clean. Commit or stash changes before releasing.');
  }
}

function runTests() {
  if (NO_TESTS || !RUN_TESTS_BEFORE) return;
  console.log('Running tests...');
  const result = spawnSync('npm', ['test'], { cwd: ROOT, stdio: 'inherit' });
  if (result.status !== 0) throw new Error('Tests failed. Aborting release.');
}

async function main() {
  ensureCleanWorkingTree();

  const pkg = loadPackageJson();
  const currentVersion = pkg.version;
  const currentTag = latestTag();
  const logRange = currentTag ? `${currentTag}..HEAD` : '--max-count=1000';

  const rawCommits = readCommits(logRange);
  const commits    = rawCommits.map(parseCommit);

  if (commits.length === 0) {
    throw new Error('No commits since last release. Nothing to release.');
  }

  const failing = checkQuality(commits);
  if (failing.length > 0) failQuality(failing);

  runTests();

  const detectedBump = FORCED_BUMP ?? detectBumpType(commits);
  const currentVer   = parseVersion(`${TAG_PREFIX}${currentVersion}`);
  const nextVer      = bump(currentVer, detectedBump);
  const nextVersion  = formatVersion(nextVer);
  const tagName      = `${TAG_PREFIX}${nextVersion}`;

  const groups  = groupCommits(commits);
  const entry   = updateChangelog(nextVersion, groups);

  console.log(`\nRelease ${tagName} (${detectedBump} from ${currentVersion}):\n`);
  console.log(entry);
  console.log('\nSummary:');
  console.log(`  bump:        ${detectedBump}`);
  console.log(`  current:     ${currentVersion}`);
  console.log(`  next:        ${nextVersion}`);
  console.log(`  commits:     ${commits.length}`);
  console.log(`  tag:         ${tagName}`);

  if (DRY_RUN) {
    console.log('\n(dry-run — no files modified, no commit, no tag)');
    return;
  }

  updatePackageVersion(nextVersion);

  git(['add', 'package.json', 'CHANGELOG.md']);
  git(['commit', '-m', `chore(release): ${tagName}`]);
  git(['tag', '-a', tagName, '-m', `Release ${tagName}`]);

  console.log(`\nCreated commit + tag ${tagName}`);

  if (AUTO_PUSH && !NO_PUSH) {
    const branch = git(['rev-parse', '--abbrev-ref', 'HEAD']);
    git(['push', 'origin', branch]);
    git(['push', 'origin', tagName]);
    console.log(`Pushed ${branch} and ${tagName}`);
  } else {
    console.log('\nTo publish:');
    console.log(`  git push origin $(git rev-parse --abbrev-ref HEAD)`);
    console.log(`  git push origin ${tagName}`);
  }
}

const invokedDirectly = import.meta.url === `file://${process.argv[1]}`;
if (invokedDirectly) {
  main().catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
}
