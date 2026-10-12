# ADR-0006 — RDS PostgreSQL with IAM authentication

**Status:** accepted

## Context
The Azure twin uses Azure SQL with Entra-only authentication. The requirement is the same: **no application password**.

## Decision
RDS for PostgreSQL (db.t4g.micro), IAM database authentication, master password managed by RDS in Secrets Manager. The API (`pg` + `@aws-sdk/rds-signer`) generates a token per connection.

## Consequences
- ✅ Passwordless app access, auditable through IAM; master password never in state.
- ⚠️ IAM DB auth is not available for RDS for SQL Server — hence PostgreSQL. (SQL Server on RDS supports AWS Managed Microsoft AD / Kerberos instead.)
- ⚠️ Token generation adds a small cost per new connection; IAM auth has connection-rate guidance — use pooling (or RDS Proxy at scale).

## Alternatives
Aurora PostgreSQL (better HA/scaling, higher cost); RDS Proxy with IAM auth to the proxy; Secrets Manager rotation with password auth.
