# Choosing a Deployment Pattern

This guide helps you select the appropriate Coder AWS deployment pattern for your use case.

## Available Patterns

### SR-HA: Single Region High Availability (v1.0 - Production Ready)

**Status:** ✅ Production-ready and validated

**Best For:**
- Production deployments with 100-500 concurrent users
- Organizations requiring high availability (99.9% uptime)
- Cost-conscious deployments needing time-based scaling
- Single geographic region

**Characteristics:**
- 3 availability zones for HA
- 2+ coderd replicas with automatic failover
- Time-based auto-scaling (06:45-18:15 ET weekdays)
- Up to 3,000 concurrent workspaces
- Spot instances for workspace nodes (70% cost savings)
- Multi-AZ Aurora PostgreSQL Serverless v2
- Estimated cost: $2,500-4,000/month

**Documentation:** [SR-HA Pattern Guide](../deployment-patterns/sr-ha/overview.md)

**When to Choose SR-HA:**
- ✅ Production workloads requiring HA
- ✅ Teams with business-hours usage patterns
- ✅ Budget: $2,500-4,000/month acceptable
- ✅ 99.9% uptime SLA requirement
- ✅ 100-500 concurrent users expected

### SR-Simple: Single Region Simple (v2.0 - Planned)

**Status:** 🚧 Planned for future release

**Best For:**
- Development/test environments
- Small teams (<20 concurrent users)
- Proof of concept deployments
- Cost minimization
- Learning and experimentation

**Characteristics:**
- 1 availability zone (no HA)
- 1 coderd replica
- No time-based auto-scaling
- Up to 100 concurrent workspaces
- On-demand instances only (no spot)
- Single-AZ Aurora PostgreSQL Serverless v2
- Estimated cost: $600-800/month

**Documentation:** [SR-Simple Pattern Guide](../deployment-patterns/sr-simple/overview.md)

**When to Choose SR-Simple:**
- ✅ Development/test environments
- ✅ Small teams (<20 users)
- ✅ Budget: <$1,000/month
- ✅ Uptime SLA not critical
- ✅ POC or evaluation phase

## Decision Matrix

| Factor | SR-HA (v1.0 ✅) | SR-Simple (v2.0 🚧) |
|--------|-----------------|---------------------|
| **Concurrent Users** | 100-500 | <20 |
| **Max Workspaces** | 3,000 | 100 |
| **Availability Zones** | 3 | 1 |
| **Uptime SLA** | 99.9% | 95% (best effort) |
| **Cost/Month** | $2,500-4,000 | $600-800 |
| **Time-Based Scaling** | Yes | No |
| **Spot Instances** | Yes (workspace nodes) | No |
| **Coderd Replicas** | 2+ | 1 |
| **Setup Time** | 60 min | 30 min |
| **Operational Complexity** | Medium | Low |
| **Production Use** | ✅ Recommended | ❌ Not recommended |

## Decision Flowchart

```
Is this for production use?
│
├─ Yes → SR-HA
│   └─ Production-ready with HA and auto-scaling
│
└─ No → Is this for dev/test or POC?
    │
    ├─ Yes → SR-Simple (when available)
    │   └─ Cost-effective for non-production
    │
    └─ No → Consider your requirements:
        ├─ Need >500 users? → Contact Coder for enterprise guidance
        ├─ Need multi-region? → Future release
        ├─ Need compliance? → Future release
        └─ Otherwise → Start with SR-HA
```

## Quick Comparison

### SR-HA vs SR-Simple

**Choose SR-HA if:**
- Production workload with uptime requirements
- >20 concurrent users expected
- Budget allows $2,500-4,000/month
- Business-hours usage pattern (benefits from time-based scaling)
- Need automatic failover and multi-AZ resilience

**Choose SR-Simple if:**
- Development/test environment only
- <20 concurrent users
- Budget constrained (<$1,000/month)
- Uptime not critical (single AZ acceptable)
- POC or evaluation phase

### Cost vs Availability Trade-off

```
                High Availability
                       ↑
                       |
                   SR-HA ($3k/mo)
                   99.9% uptime
                   3 AZs
                       |
                       |
            -----------+----------- Cost
                       |
                       |
                SR-Simple ($600/mo)
                95% uptime
                1 AZ
                       |
                Low Availability
```

## Migration Path

**Start with SR-Simple → Migrate to SR-HA:**
- Suitable for: POC → Production transition
- Downtime: 15-30 minutes (for AZ migration)
- Procedure: See [SR-HA Overview - Migration from SR-Simple](../deployment-patterns/sr-ha/overview.md#migration-from-sr-simple)

**Start with SR-HA:**
- Suitable for: Production from day 1
- No migration needed
- Recommended for most deployments

## Next Steps

Once you've selected a pattern:

1. **Review prerequisites:** [Prerequisites Guide](./prerequisites.md)
2. **Follow the quickstart:** [60-Minute Deployment](./quickstart.md)
3. **Read the pattern-specific guide:**
   - [SR-HA Deployment](../deployment-patterns/sr-ha/deployment.md) ✅ Available now
   - [SR-Simple Deployment](../deployment-patterns/sr-simple/deployment.md) 🚧 Coming in v2.0

## Related Documentation

- [Architecture Overview](./overview.md)
- [Prerequisites](./prerequisites.md)
- [SR-HA Capacity Planning](../deployment-patterns/sr-ha/capacity-planning.md)
- [Cost Estimation](../reference/cost-estimation.md)
- [FAQ](../reference/faq.md)
