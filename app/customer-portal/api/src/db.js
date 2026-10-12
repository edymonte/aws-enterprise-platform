'use strict';

// Amazon RDS for PostgreSQL WITHOUT passwords.
//
// In EKS, the Pod Identity agent exposes temporary credentials for the role
// associated with this pod's ServiceAccount (AWS_CONTAINER_CREDENTIALS_FULL_URI).
// The RDS Signer uses them to create a 15-minute IAM authentication token,
// which is sent as the PostgreSQL password. The DB user 'portal_api' was
// granted the 'rds_iam' role (scripts/db-grant-app-user.ps1), and the IAM
// policy allows rds-db:connect only for that user (infra/terraform/40-eks).
//
// Without PGHOST (local dev / unit tests) an in-memory catalog is used.

const fs = require('node:fs');

const MEMORY_PRODUCTS = [
  { id: 1, name: 'Digital Account', category: 'banking' },
  { id: 2, name: 'Platinum Card', category: 'cards' },
  { id: 3, name: 'Fixed Income Fund', category: 'investments' },
];

let poolPromise;

function mode() {
  return process.env.PGHOST ? 'rds-postgres' : 'in-memory';
}

function buildPool() {
  // Lazy requires: unit tests run without these code paths.
  const { Pool } = require('pg');
  const { Signer } = require('@aws-sdk/rds-signer');

  const host = process.env.PGHOST;
  const port = Number(process.env.PGPORT || 5432);
  const user = process.env.PGUSER || 'portal_api';
  const signer = new Signer({ hostname: host, port, username: user, region: process.env.AWS_REGION });

  const caFile = process.env.PGSSLROOTCERT || '/app/certs/rds-ca.pem';
  return new Pool({
    host,
    port,
    user,
    database: process.env.PGDATABASE || 'portal',
    password: () => signer.getAuthToken(), // new token per connection (valid 15 min)
    ssl: { rejectUnauthorized: true, ca: fs.readFileSync(caFile, 'utf8') }, // IAM auth requires TLS
    max: 5,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
  });
}

function getPool() {
  if (!poolPromise) {
    poolPromise = (async () => {
      const pool = buildPool();
      await ensureSchema(pool);
      return pool;
    })().catch((err) => {
      poolPromise = undefined; // retry on next call
      throw err;
    });
  }
  return poolPromise;
}

async function ensureSchema(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS products (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100) NOT NULL,
      category VARCHAR(50) NOT NULL
    )`);
  const { rows } = await pool.query('SELECT COUNT(*)::int AS n FROM products');
  if (rows[0].n === 0) {
    await pool.query(
      `INSERT INTO products (name, category) VALUES
        ('Digital Account', 'banking'), ('Platinum Card', 'cards'), ('Fixed Income Fund', 'investments')`,
    );
  }
}

async function ping() {
  if (mode() === 'in-memory') return;
  const pool = await getPool();
  await pool.query('SELECT 1');
}

async function listProducts() {
  if (mode() === 'in-memory') return MEMORY_PRODUCTS;
  const pool = await getPool();
  const { rows } = await pool.query('SELECT id, name, category FROM products ORDER BY id');
  return rows;
}

module.exports = { mode, ping, listProducts };
