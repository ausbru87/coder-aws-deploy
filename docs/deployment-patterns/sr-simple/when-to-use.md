# When to Use SR-Simple

**Status:** 🚧 Future (Planned for v2.0)

## Decision Framework

Use this guide to determine if SR-Simple is the right pattern for your use case.

## Ideal Use Cases

### ✅ Development Environments

**Scenario:** Engineering teams need an isolated environment for testing infrastructure changes before production.

**Why SR-Simple works:**
- Quick setup/teardown (30-45 min deploy, 10 min destroy)
- Low cost (~$400-800/month) vs SR-HA (~$2,500-4,000/month)
- Full feature parity with production patterns for testing
- Isolated blast radius for experimentation

**Example:**
```bash
# Deploy dev environment
terraform workspace new dev
terraform apply -var-file=patterns/sr-simple.tfvars -var="environment=dev"

# Test infrastructure changes
# ...

# Tear down when done
terraform destroy -auto-approve
```

### ✅ Proof of Concept (POC)

**Scenario:** Evaluating Coder for organizational adoption with a small pilot group.

**Why SR-Simple works:**
- Minimal upfront investment
- Quick time-to-value (deployed in 1 hour)
- Supports 10-20 pilot users comfortably
- Easy migration to SR-HA if POC succeeds

**POC timeline:**
- Week 1: Deploy SR-Simple, onboard 5 early adopters
- Week 2-4: Expand to 20 users, gather feedback
- Week 5: Decision point (migrate to SR-HA or decommission)

### ✅ Training and Workshops

**Scenario:** Delivering hands-on training sessions or workshops for Coder.

**Why SR-Simple works:**
- Ephemeral deployment (spin up/down as needed)
- Supports 10-30 concurrent workshop attendees
- Low cost for short-duration events
- Predictable performance for scripted demos

**Workshop pattern:**
```bash
# 1 week before workshop: Deploy
terraform apply -var-file=patterns/sr-simple.tfvars

# Day of workshop: Verify capacity
kubectl get nodes
coder templates list

# After workshop: Tear down
terraform destroy
```

### ✅ Small Teams (<20 developers)

**Scenario:** Startup or small team with limited infrastructure budget.

**Why SR-Simple works:**
- 75-85% cost savings vs SR-HA
- Sufficient capacity for <100 workspaces
- Lower operational complexity (fewer moving parts)
- Upgrade path to SR-HA as team grows

**Growth triggers for migration:**
- Team size exceeds 30 developers
- Concurrent workspaces exceed 80
- Business requires >95% uptime SLA
- Geographic distribution requires multi-region

## Not Recommended For

### ❌ Production Workloads

**Why SR-Simple is insufficient:**
- **No high availability:** Single AZ failure = complete outage
- **No automatic failover:** Manual intervention required for recovery
- **Limited capacity:** Max 100 workspaces (SR-HA supports 3,000)
- **No cost optimization:** No time-based scaling

**Alternative:** Use [SR-HA pattern](../sr-ha/overview.md) for production.

### ❌ Mission-Critical Applications

**Why SR-Simple is insufficient:**
- **Single points of failure:** NAT Gateway, Aurora single-AZ, single coderd replica
- **No disaster recovery:** No cross-region backup replication
- **Limited monitoring:** Minimal observability compared to SR-HA
- **No SLA guarantees:** Best-effort availability

**Alternative:** Use [SR-HA pattern](../sr-ha/overview.md) with enhanced monitoring.

### ❌ Large Teams (>50 users)

**Why SR-Simple is insufficient:**
- **Capacity limits:** Max 100 workspaces, but performance degrades >80
- **Provisioning bottleneck:** Single provisioner node = slow workspace creation
- **Database constraints:** Aurora max 4 ACU limits concurrent connections
- **Network limits:** Single NAT Gateway = 5 Gbps burst cap

**Alternative:** Use [SR-HA pattern](../sr-ha/overview.md) or [Multi-Region](../multi-region/overview.md).

### ❌ Regulated Industries

**Why SR-Simple is insufficient:**
- **Compliance gaps:** No audit logging, short backup retention (7 days vs 365)
- **Security controls:** Missing VPC endpoints, GuardDuty, Security Hub
- **Encryption:** Standard encryption (PubSec requires FIPS 140-2)
- **Data residency:** No cross-region isolation guarantees

**Alternative:** Use [PubSec pattern](../pubsec/overview.md) for regulated workloads.

## Comparison Matrix

| Criterion | SR-Simple | SR-HA | Multi-Region | PubSec |
|-----------|-----------|-------|--------------|--------|
| **Cost** | $ | $$$ | $$$$ | $$$$ |
| **Deployment Time** | 30-45 min | 60 min | 90 min | 90 min |
| **Max Users** | 20 | 500 | 2,000 | 500 |
| **Max Workspaces** | 100 | 3,000 | 10,000 | 3,000 |
| **Availability** | 95% | 99.9% | 99.95% | 99.9% |
| **Disaster Recovery** | None | Regional | Global | Regional |
| **Compliance** | Basic | Standard | Standard | Enhanced |
| **Operational Complexity** | Low | Medium | High | Medium |

## Migration Decision Tree

```
Are you deploying to production?
├─ No → SR-Simple ✅
└─ Yes → Do you need >99% uptime?
    ├─ No → SR-Simple (with monitoring plan)
    └─ Yes → Do you have users in multiple regions?
        ├─ No → SR-HA ✅
        └─ Yes → Are you in a regulated industry?
            ├─ No → Multi-Region ✅
            └─ Yes → PubSec + Multi-Region ✅
```

## Cost-Benefit Analysis

### Scenario 1: 10-Developer Startup

**Requirements:**
- 10 developers, 20-30 workspaces
- Development/staging workloads only
- Limited budget (<$1,000/month for infrastructure)

**Recommendation:** SR-Simple
- **Cost:** ~$600/month
- **Risk:** Low (non-production)
- **Migration trigger:** Series A funding or >30 developers

### Scenario 2: 100-Developer Scale-Up

**Requirements:**
- 100 developers, 200-300 workspaces
- Production workloads
- Business-hours usage (9am-6pm ET)

**Recommendation:** SR-HA
- **Cost:** ~$3,000/month (with time-based scaling)
- **Risk:** Medium (production, but single region)
- **Migration trigger:** Geographic expansion or >500 developers

### Scenario 3: Enterprise (500+ Developers)

**Requirements:**
- 500+ developers across US, EU, APAC
- Mission-critical production workloads
- 24/7 global availability required
- GDPR, SOC 2, ISO 27001 compliance

**Recommendation:** Multi-Region + PubSec
- **Cost:** ~$12,000/month (3 regions)
- **Risk:** Low (full HA + DR)
- **Migration trigger:** None (final state architecture)

## Questions to Ask

Before choosing SR-Simple, answer these questions:

1. **What is the cost of downtime?**
   - <$1,000/hour → SR-Simple acceptable
   - >$1,000/hour → SR-HA required

2. **How many concurrent users?**
   - <20 users → SR-Simple sufficient
   - 20-500 users → SR-HA recommended
   - >500 users → Multi-Region required

3. **What is the expected growth rate?**
   - Slow (<10% per quarter) → SR-Simple with monitoring
   - Fast (>25% per quarter) → Start with SR-HA to avoid migration

4. **Are you in a regulated industry?**
   - No → SR-Simple or SR-HA
   - Yes → PubSec required (skip SR-Simple)

5. **Do you have geographic distribution?**
   - Single region → SR-Simple or SR-HA
   - Multi-region → Multi-Region pattern

## Related Documentation

- [SR-Simple Overview](./overview.md)
- [SR-Simple Deployment Guide](./deployment.md)
- [Choosing a Pattern](../../getting-started/choosing-a-pattern.md)
- [SR-HA Pattern](../sr-ha/overview.md)
- [Cost Estimation](../../reference/cost-estimation.md)
