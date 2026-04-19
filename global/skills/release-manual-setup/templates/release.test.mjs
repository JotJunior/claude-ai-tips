import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import {
  parseCommit,
  detectBumpType,
  checkQuality,
  formatEntry,
  groupCommits,
  bump,
} from '../scripts/release.mjs';

const LONG_BODY = 'This is a sufficiently long body that explains why the change was made.';

describe('parseCommit', () => {
  it('parses a feat commit', () => {
    const c = parseCommit({ hash: 'abc1234', subject: 'feat(cli): add new command', body: LONG_BODY });
    assert.equal(c.type, 'feat');
    assert.equal(c.scope, 'cli');
    assert.equal(c.breaking, false);
    assert.equal(c.description, 'add new command');
    assert.equal(c.body, LONG_BODY);
  });

  it('parses a fix commit without scope', () => {
    const c = parseCommit({ hash: 'abc1234', subject: 'fix: correct null check', body: LONG_BODY });
    assert.equal(c.type, 'fix');
    assert.equal(c.scope, null);
  });

  it('detects breaking change from bang operator', () => {
    const c = parseCommit({ hash: 'abc1234', subject: 'feat!: breaking feature', body: LONG_BODY });
    assert.equal(c.breaking, true);
    assert.equal(c.type, 'feat');
  });

  it('detects breaking change from BREAKING CHANGE in body', () => {
    const c = parseCommit({ hash: 'abc1234', subject: 'feat: something', body: 'BREAKING CHANGE: removes old API' });
    assert.equal(c.breaking, true);
  });

  it('handles non-conventional commit subject', () => {
    const c = parseCommit({ hash: 'abc1234', subject: 'random commit message', body: '' });
    assert.equal(c.type, null);
    assert.equal(c.breaking, false);
    assert.equal(c.description, 'random commit message');
  });

  it('parses chore commit', () => {
    const c = parseCommit({ hash: 'abc1234', subject: 'chore(deps): update lockfile', body: '' });
    assert.equal(c.type, 'chore');
    assert.equal(c.scope, 'deps');
  });
});

describe('detectBumpType', () => {
  it('returns patch for only fix commits', () => {
    const commits = [
      parseCommit({ hash: 'a', subject: 'fix: null check', body: LONG_BODY }),
      parseCommit({ hash: 'b', subject: 'chore: lint', body: '' }),
    ];
    assert.equal(detectBumpType(commits), 'patch');
  });

  it('returns minor when any feat is present', () => {
    const commits = [
      parseCommit({ hash: 'a', subject: 'feat: new feature', body: LONG_BODY }),
      parseCommit({ hash: 'b', subject: 'fix: something', body: LONG_BODY }),
    ];
    assert.equal(detectBumpType(commits), 'minor');
  });

  it('returns major when any breaking change is present', () => {
    const commits = [
      parseCommit({ hash: 'a', subject: 'fix: something', body: LONG_BODY }),
      parseCommit({ hash: 'b', subject: 'feat!: breaking', body: LONG_BODY }),
    ];
    assert.equal(detectBumpType(commits), 'major');
  });

  it('major takes precedence over minor', () => {
    const commits = [
      parseCommit({ hash: 'a', subject: 'feat: new thing', body: LONG_BODY }),
      parseCommit({ hash: 'b', subject: 'feat!: breaking', body: LONG_BODY }),
    ];
    assert.equal(detectBumpType(commits), 'major');
  });
});

describe('checkQuality', () => {
  it('accepts feat with long body', () => {
    const c = parseCommit({ hash: 'a', subject: 'feat: new', body: LONG_BODY });
    assert.equal(checkQuality([c]).length, 0);
  });

  it('rejects feat without body', () => {
    const c = parseCommit({ hash: 'a', subject: 'feat: new', body: '' });
    assert.equal(checkQuality([c]).length, 1);
  });

  it('rejects fix with short body', () => {
    const c = parseCommit({ hash: 'a', subject: 'fix: bug', body: 'short' });
    assert.equal(checkQuality([c]).length, 1);
  });

  it('accepts chore without body', () => {
    const c = parseCommit({ hash: 'a', subject: 'chore: lint', body: '' });
    assert.equal(checkQuality([c]).length, 0);
  });

  it('rejects breaking without body regardless of type', () => {
    const c = parseCommit({ hash: 'a', subject: 'refactor!: break', body: '' });
    assert.equal(checkQuality([c]).length, 1);
  });
});

describe('formatEntry', () => {
  it('formats entry without body', () => {
    const c = parseCommit({ hash: 'a', subject: 'feat: x', body: '' });
    assert.equal(formatEntry(c), '- **x**');
  });

  it('formats entry with body', () => {
    const c = parseCommit({ hash: 'a', subject: 'feat: x', body: 'body text' });
    assert.ok(formatEntry(c).startsWith('- **x**'));
    assert.ok(formatEntry(c).includes('body text'));
  });

  it('collapses multi-line body into single paragraph', () => {
    const c = parseCommit({ hash: 'a', subject: 'feat: x', body: 'line1\n\nline2\n  line3' });
    const formatted = formatEntry(c);
    assert.ok(formatted.includes('line1 line2 line3'));
  });
});

describe('groupCommits', () => {
  it('separates commits by type', () => {
    const commits = [
      parseCommit({ hash: 'a', subject: 'feat: x', body: LONG_BODY }),
      parseCommit({ hash: 'b', subject: 'fix: y', body: LONG_BODY }),
      parseCommit({ hash: 'c', subject: 'chore: z', body: '' }),
    ];
    const groups = groupCommits(commits);
    assert.equal(groups.feat.length, 1);
    assert.equal(groups.fix.length, 1);
    assert.equal(groups.chore.length, 1);
    assert.equal(groups.breaking.length, 0);
  });

  it('routes breaking to breaking group regardless of type', () => {
    const commits = [parseCommit({ hash: 'a', subject: 'feat!: x', body: LONG_BODY })];
    const groups = groupCommits(commits);
    assert.equal(groups.breaking.length, 1);
    assert.equal(groups.feat.length, 0);
  });
});

describe('bump (pre-1.0 mode)', () => {
  it('patch in 0.x', () => {
    assert.deepEqual(bump({ major: 0, minor: 5, patch: 3 }, 'patch'), { major: 0, minor: 5, patch: 4 });
  });

  it('minor in 0.x', () => {
    assert.deepEqual(bump({ major: 0, minor: 5, patch: 3 }, 'minor'), { major: 0, minor: 6, patch: 0 });
  });

  it('major in 0.x as minor (default)', () => {
    assert.deepEqual(bump({ major: 0, minor: 5, patch: 3 }, 'major'), { major: 0, minor: 6, patch: 0 });
  });

  it('major in 1.x+', () => {
    assert.deepEqual(bump({ major: 1, minor: 5, patch: 3 }, 'major'), { major: 2, minor: 0, patch: 0 });
  });
});
