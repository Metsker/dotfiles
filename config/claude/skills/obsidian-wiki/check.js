#!/usr/bin/env node
// Reports unresolved links, unresolved embeds and malformed frontmatter in an Obsidian vault.
// Usage: check.js <vault name or path>   (vault names resolve under ~/notes/obsidian)
const fs = require('fs'), path = require('path'), os = require('os');

const arg = process.argv[2] || 'brain';
const VAULT = fs.existsSync(arg) ? path.resolve(arg) : path.join(os.homedir(), 'notes/obsidian', arg);
if (!fs.existsSync(VAULT)) { console.error(`no such vault: ${VAULT}`); process.exit(2); }

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === '.obsidian' || e.name === '.git') continue;
    const p = path.join(dir, e.name);
    e.isDirectory() ? walk(p, out) : out.push(p);
  }
  return out;
}

const files = walk(VAULT);
// A link resolves against a full vault-relative path or a bare filename, with or without .md.
const targets = new Set();
for (const f of files) {
  const rel = f.slice(VAULT.length + 1);
  for (const n of [rel, rel.replace(/\.md$/, ''), path.basename(rel), path.basename(rel, '.md')]) targets.add(n);
}

const badFm = [], badLink = [], badEmbed = [];
for (const f of files.filter(f => f.endsWith('.md'))) {
  const text = fs.readFileSync(f, 'utf8'), rel = f.slice(VAULT.length + 1);

  if (text.startsWith('---\n')) {
    const end = text.indexOf('\n---', 3);
    if (end < 0) badFm.push(`${rel}: unterminated frontmatter`);
    else for (const line of text.slice(4, end).split('\n')) {
      if (line.trim() && !/^([A-Za-z_][\w.-]*:|\s+-\s|\s+\S)/.test(line)) badFm.push(`${rel}: ${line}`);
    }
  }

  // Base and search blocks contain property names that look like links; skip them.
  const body = text.replace(/```(base|query|dataview)[\s\S]*?```/g, '');
  for (const m of body.matchAll(/(!?)\[\[([^\]|#]+)/g)) {
    const target = m[2].trim();
    if (targets.has(target) || targets.has(`${target}.md`)) continue;
    (m[1] ? badEmbed : badLink).push(`${rel} -> ${target}`);
  }
}

const report = (label, list) => {
  console.log(`${String(list.length).padStart(4)}  ${label}`);
  for (const line of [...new Set(list)]) console.log(`      ${line}`);
};
console.log(`${VAULT}: ${files.filter(f => f.endsWith('.md')).length} notes`);
report('malformed frontmatter', badFm);
report('unresolved links', badLink);
report('unresolved embeds', badEmbed);

process.exit(badFm.length + badLink.length + badEmbed.length ? 1 : 0);
