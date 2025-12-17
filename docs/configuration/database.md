# Database Architecture and Configuration

This document covers Aurora PostgreSQL configuration for Coder deployments.

## Aurora PostgreSQL Serverless v2

- **Engine Version:** 16.4
- **Min ACU:** 0.5 (1 GB RAM)
- **Max ACU:** 16 (32 GB RAM)
- **Multi-AZ:** Enabled for SR-HA
- **Backup Retention:** 90 days minimum
- **Encryption:** At rest (AWS KMS) and in transit (TLS)

## Capacity Scaling

Aurora Serverless v2 automatically scales based on:
- CPU utilization
- Memory pressure
- Connection count
- Database IOPS

Typical ACU usage:
- **Idle:** 0.5-1 ACU
- **Light load (<100 users):** 1-2 ACU
- **Medium load (100-500 users):** 2-4 ACU
- **Heavy load (500+ users):** 4-16 ACU

## Connection Pooling

- Coder uses PgBouncer connection pooling
- Default pool size: 20 connections
- Scales with coderd replica count

## Backup Strategy

### Automated Backups

- Daily automated snapshots
- Point-in-time recovery (PITR) enabled
- 90-day retention (SR-HA)


Key CloudWatch metrics:
- `DatabaseConnections`
- `CPUUtilization`
- `ServerlessDatabaseCapacity` (ACU count)
- `FreeableMemory`

## Related Documentation

- [Architecture Overview](../getting-started/overview.md)
- [Day 2 Operations](../operations/day2-operations.md)
- [Troubleshooting](../operations/troubleshooting.md)
