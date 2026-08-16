// One-shot migration runner. Designed for the first boot on a fresh Render
// Postgres instance, but safe to re-run (every CREATE / ALTER uses IF NOT EXISTS
// and every index uses IF NOT EXISTS).
//
// Usage: enable by setting DB_BOOTSTRAP=1 in the service env. The runner will:
//   1) create the schema in `database/tables/*.sql` (in lexical order)
//   2) apply `database/migrations/*.sql` (in lexical order)
//
// All statements are sent through pg as individual queries, so BEGIN/COMMIT
// wrappers and psql meta-commands (`\i`, `\echo`, `\\`) are stripped before
// execution.

const fs = require('fs');
const path = require('path');
const { pool } = require('../config/db');

// Resolve repo root from this file: backend/src/db/migrate.js -> repo root.
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const DB_DIR = path.join(REPO_ROOT, 'database');
const TABLES_DIR = path.join(DB_DIR, 'tables');
const MIGRATIONS_DIR = path.join(DB_DIR, 'migrations');

/**
 * Strip psql meta-commands (`\i ...`, `\echo ...`, `\\`) and explicit
 * transaction markers (BEGIN/COMMIT/END). pg already runs every query inside
 * an implicit transaction, so we don't need them.
 */
function normaliseSql(raw) {
  return raw
    .split('\n')
    .filter((line) => {
      const t = line.trim();
      if (t.startsWith('\\')) return false; // psql meta
      return true;
    })
    .join('\n')
    .replace(/^\s*BEGIN\s*;?\s*$/gim, '')
    .replace(/^\s*COMMIT\s*;?\s*$/gim, '')
    .replace(/^\s*END\s*;?\s*$/gim, '');
}

/**
 * Split a SQL script into individual statements, respecting single-quoted
 * strings and dollar-quoted blocks. Returns an array of trimmed strings.
 */
function splitStatements(sql) {
  const stmts = [];
  let buf = '';
  let i = 0;
  const n = sql.length;
  let inSingle = false;
  let inDouble = false;
  let dollarTag = null;

  while (i < n) {
    const ch = sql[i];
    const next = sql[i + 1];

    if (!inSingle && !inDouble && ch === '$') {
      const rest = sql.slice(i);
      const m = rest.match(/^\$([A-Za-z0-9_]*)\$/);
      if (m) {
        dollarTag = '$' + (m[1] || '') + '$';
        buf += dollarTag;
        i += dollarTag.length;
        continue;
      }
    }
    if (dollarTag && ch === '$') {
      const rest = sql.slice(i);
      if (rest.startsWith(dollarTag)) {
        buf += dollarTag;
        i += dollarTag.length;
        dollarTag = null;
        continue;
      }
    }

    if (!dollarTag) {
      if (!inDouble && ch === "'" && sql[i - 1] !== '\\') {
        if (inSingle && next === "'") {
          buf += "''";
          i += 2;
          continue;
        }
        inSingle = !inSingle;
      } else if (!inSingle && ch === '"' && sql[i - 1] !== '\\') {
        inDouble = !inDouble;
      }

      if (ch === ';' && !inSingle && !inDouble) {
        const stmt = buf.trim();
        if (stmt) stmts.push(stmt);
        buf = '';
        i++;
        continue;
      }
    }

    buf += ch;
    i++;
  }
  const tail = buf.trim();
  if (tail) stmts.push(tail);
  return stmts;
}

async function runFile(filePath, label) {
  const raw = fs.readFileSync(filePath, 'utf8');
  const sql = normaliseSql(raw);
  const stmts = splitStatements(sql);
  // eslint-disable-next-line no-console
  console.log(
    `[migrate] ${label}: ${path.relative(REPO_ROOT, filePath)} (${stmts.length} stmts)`
  );
  for (const stmt of stmts) {
    try {
      await pool.query(stmt);
    } catch (err) {
      const preview = stmt.replace(/\s+/g, ' ').slice(0, 120);
      // eslint-disable-next-line no-console
      console.error(
        `[migrate] FAILED in ${path.relative(REPO_ROOT, filePath)}: ${err.message}`
      );
      // eslint-disable-next-line no-console
      console.error(`  > ${preview}...`);
      throw err;
    }
  }
}

async function migrate() {
  const tables = fs
    .readdirSync(TABLES_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  for (const f of tables) {
    await runFile(path.join(TABLES_DIR, f), 'table');
  }

  const migrations = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  for (const f of migrations) {
    await runFile(path.join(MIGRATIONS_DIR, f), 'migrate');
  }
}

module.exports = { migrate, normaliseSql, splitStatements };

if (require.main === module) {
  // eslint-disable-next-line no-console
  migrate()
    .then(() => {
      // eslint-disable-next-line no-console
      console.log('[migrate] done');
      process.exit(0);
    })
    .catch((err) => {
      // eslint-disable-next-line no-console
      console.error('[migrate] error:', err.message);
      process.exit(1);
    });
}