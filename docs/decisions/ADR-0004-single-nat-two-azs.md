# ADR-0004 — Two AZs with a single NAT gateway

**Status:** accepted (lab trade-off)

## Decision
Subnets in two AZs (nodes, ALB and RDS subnet group span both), but one NAT gateway.

## Consequences
- ✅ Compute and load balancing survive an AZ failure; cost of only one NAT.
- ⚠️ Egress depends on one AZ: if it fails, workloads in the other AZ lose internet (image pulls from public registries, third-party APIs).

## Production
One NAT per AZ (`single_nat_gateway = false`), interface endpoints for AWS APIs, three AZs, and centralized egress/inspection through Transit Gateway in multi-VPC estates.
