# Architecture Decision Records (ADRs)

This document tracks key architectural decisions made during the design and implementation of the Coder AWS deployment architecture.

## ADR-001: Feature Flags Over Overlay Modules

**Date:** 2025-01-15
**Status:** Accepted
**Context:** Need to support multiple deployment patterns (SR-HA, SR-Simple) from a single codebase with flexibility for future patterns.

**Decision:**
Use feature flags (`deployment_features` object) with conditional logic in Terraform modules instead of separate overlay modules or repositories.

```hcl
deployment_features = {
  high_availability  = bool  # 3 AZs vs 1 AZ
  time_based_scaling = bool  # Auto-scaling schedules
}
```

**Rationale:**
- Most Terraform-native approach (no overlay complexity)
- Single root module with conditional logic based on flags
- Pre-built tfvars for common patterns (sr-ha, sr-simple)
- Easy to test (single module)
- Users can compose patterns by enabling different flag combinations

**Consequences:**
- ✅ Simplified testing and validation
- ✅ Single source of truth for all patterns
- ✅ Easy composition of features (can add more flags in future)
- ✅ User-friendly pattern selection via pre-built tfvars files
- ❌ Increased complexity in module conditional logic
- ❌ Requires careful documentation of flag interactions

**Alternatives Considered:**
1. **Terraform Overlays (Terragrunt):** Too complex, steep learning curve
2. **Separate Repositories:** Independent versioning but duplication and drift
3. **Git Submodules:** Complex dependency management

---

## ADR-002: Aurora Serverless v2 Over Provisioned Aurora

**Date:** 2024-12-01  
**Status:** Accepted  
**Context:** Need cost-effective database solution that scales with workload.

**Decision:**  
Use Aurora PostgreSQL Serverless v2 (0.5-16 ACU) instead of provisioned Aurora instances.

**Rationale:**
- **Cost savings:** ~60% cheaper for variable workloads (scales down to 0.5 ACU during off-hours)
- **Automatic scaling:** No manual capacity planning for database
- **Pay-per-use:** Charged per ACU-hour, not per instance hour
- **Quick scaling:** Scales up/down in seconds vs minutes for provisioned instances

**Capacity Planning:**
- Idle: 0.5-1 ACU (~$45-90/month)
- Light load (<100 users): 1-2 ACU (~$90-180/month)
- Medium load (100-500 users): 2-4 ACU (~$180-360/month)
- Heavy load (500+ users): 4-16 ACU (~$360-1,440/month)

**Consequences:**
- ✅ Significant cost savings for variable workloads
- ✅ No database capacity planning required
- ✅ Automatic scaling during traffic spikes
- ❌ Cold start penalty if scaled to 0 ACU (not recommended for production)
- ❌ Max 16 ACU may bottleneck at extreme scale (use provisioned for >16 ACU needs)

**Alternatives Considered:**
1. **Provisioned r6g.large:** Fixed cost ~$500/month, no scaling
2. **Aurora Serverless v1:** Deprecated, slow scaling (minutes)
3. **RDS PostgreSQL:** No multi-AZ automatic failover like Aurora

---

## ADR-003: Time-Based Scaling for SR-HA Pattern

**Date:** 2024-11-15  
**Status:** Accepted  
**Context:** Need to reduce EKS costs during off-peak hours for business-hours-focused teams.

**Decision:**  
Implement time-based auto-scaling for provisioner and workspace node groups (scale up at 06:45 ET, down at 18:15 ET).

**Rationale:**
- **Cost savings:** ~40-55% reduction in EC2 costs for teams with business-hours usage
- **Pre-warming:** 15-minute lead time ensures infrastructure ready at 07:00
- **Predictable:** Deterministic scaling schedule vs reactive auto-scaling
- **Simple:** AWS Auto Scaling Schedules vs complex Karpenter configuration

**Schedule:**
```hcl
scaling_schedule = {
  start_time = "45 6 * * MON-FRI"  # 06:45 ET
  stop_time  = "15 18 * * MON-FRI"  # 18:15 ET
  timezone   = "America/New_York"
}
```

**Consequences:**
- ✅ Significant cost savings (~$8,690/month for 50-node deployment)
- ✅ Infrastructure ready when users arrive
- ✅ Simple implementation (AWS native)
- ❌ Not suitable for 24/7 workloads
- ❌ Requires manual override for off-hours work

**Alternatives Considered:**
1. **Cluster Autoscaler:** Reactive, unpredictable scaling behavior
2. **Karpenter:** Complex, requires additional setup and maintenance
3. **No scaling:** 24/7 peak capacity = high cost

---

## ADR-004: Spot Instances for Workspace Nodes

**Date:** 2024-11-01  
**Status:** Accepted  
**Context:** Need to reduce EC2 costs while maintaining workspace availability.

**Decision:**  
Use spot instances for workspace nodes with on-demand fallback for SR-HA pattern.

**Rationale:**
- **Cost savings:** ~70% discount vs on-demand pricing
- **Availability:** Spot instances historically >95% available for m5.2xlarge
- **Graceful degradation:** On-demand instances launch if spot unavailable
- **Workspace resilience:** Coder workspaces automatically reconnect after spot interruptions

**Configuration:**
```hcl
capacity_type       = "SPOT"
instance_types      = ["m5.2xlarge", "m5a.2xlarge", "m5n.2xlarge"]  # Multiple types for flexibility
on_demand_percentage = 20  # 20% on-demand for stability
```

**Consequences:**
- ✅ Significant cost savings (~$10,000/month for 50-node deployment)
- ✅ Multiple instance types increase spot availability
- ✅ Coder handles spot interruptions gracefully (workspace reconnects)
- ❌ Occasional spot interruptions (2-5% of instances)
- ❌ Not suitable for PubSec pattern (compliance requires on-demand)

**Alternatives Considered:**
1. **100% on-demand:** Stable but expensive
2. **100% spot:** Higher risk of capacity issues
3. **Reserved Instances:** Requires upfront commitment

---

## ADR-005: Single Repository for All Patterns

**Date:** 2025-01-15  
**Status:** Accepted  
**Context:** Need to organize codebase for multiple deployment patterns.

**Decision:**  
Keep all deployment patterns in a single repository during v1 validation phase.

**Rationale:**
- **Rapid iteration:** Easier to refactor modules during AWS validation (2 weeks)
- **Atomic changes:** Single PR can update multiple patterns
- **Simplified testing:** Single CI/CD pipeline for all patterns
- **Lower barrier:** Users clone one repo vs managing multiple repos

**Repository Structure:**
```
coder-aws-deployment/
├── modules/         # Reusable modules
├── patterns/        # Pre-built tfvars (sr-ha, sr-simple, etc.)
├── examples/        # Usage examples
└── docs/            # Documentation
```

**Consequences:**
- ✅ Faster development iteration
- ✅ Easier for users to get started
- ✅ Single CI/CD pipeline
- ❌ Larger repository size
- ❌ Tighter coupling between patterns

**Future Consideration:**  
After 3-6 months of validation, consider splitting into:
- `coder-aws-base` (core modules)
- `coder-aws-patterns` (deployment patterns)
- `coder-aws-examples` (compositions)

**Alternatives Considered:**
1. **Multi-repo from day 1:** Too complex during validation phase
2. **Monorepo with workspaces:** Adds Terraform workspace complexity
3. **Terraform Registry modules:** Requires publishing workflow setup

---

## ADR-006: VPC Endpoints for PubSec Pattern

**Date:** 2024-12-10  
**Status:** Accepted  
**Context:** PubSec compliance requires network isolation and audit logging.

**Decision:**  
Require VPC endpoints for all AWS API calls in PubSec pattern instead of NAT Gateway egress.

**Rationale:**
- **Compliance:** AWS API calls stay within AWS network (no internet egress)
- **Audit logging:** CloudTrail logs all API calls with source VPC endpoint
- **Security:** Reduces attack surface for lateral movement
- **Cost neutral:** VPC endpoint costs (~$200/month) similar to NAT Gateway costs

**Endpoints Required:**
- ec2, ecr.api, ecr.dkr (EKS node communication)
- s3 (gateway endpoint, no cost)
- logs (CloudWatch Logs)
- sts (IAM authentication)
- kms (encryption key access)

**Consequences:**
- ✅ Enhanced network isolation
- ✅ Compliance with regulated industry requirements
- ✅ Improved audit logging
- ❌ Slightly more complex network architecture
- ❌ Some AWS services don't support VPC endpoints (requires NAT Gateway)

**Alternatives Considered:**
1. **NAT Gateway only:** Doesn't meet compliance requirements
2. **AWS PrivateLink for all services:** Not all services support PrivateLink
3. **Proxy-based egress filtering:** More complex, higher operational overhead

---

## ADR-007: Kubernetes Over ECS for Workspace Orchestration

**Date:** 2024-10-01  
**Status:** Accepted  
**Context:** Need to choose container orchestration platform for Coder workspaces.

**Decision:**  
Use Amazon EKS (Kubernetes) instead of ECS for workspace orchestration.

**Rationale:**
- **Coder native support:** Coder has first-class Kubernetes provider
- **Resource management:** Fine-grained CPU/memory limits and requests
- **Networking:** Pod networking with NetworkPolicies for isolation
- **Flexibility:** Support for both Kubernetes pods and EC2 workspaces
- **Ecosystem:** Rich ecosystem of tools (Helm, Kustomize, operators)

**Consequences:**
- ✅ Native Coder integration
- ✅ Fine-grained resource control
- ✅ Strong network isolation
- ✅ Large ecosystem and community
- ❌ Higher operational complexity than ECS
- ❌ Requires Kubernetes expertise

**Alternatives Considered:**
1. **ECS:** Simpler but limited Coder integration
2. **ECS Fargate:** No control over node capacity, higher cost
3. **Raw EC2:** No orchestration, complex operational overhead

---

## Template

```markdown
## ADR-XXX: Title

**Date:** YYYY-MM-DD  
**Status:** Proposed | Accepted | Deprecated | Superseded  
**Context:** [Why is this decision needed?]

**Decision:**  
[What is the decision?]

**Rationale:**
[Why was this decision made?]

**Consequences:**
- ✅ [Positive consequences]
- ❌ [Negative consequences]

**Alternatives Considered:**
1. [Alternative 1]
2. [Alternative 2]
```

---

## Related Documentation

- [Feature Flags Reference](../configuration/feature-flags.md)
- [SR-HA Pattern](../deployment-patterns/sr-ha/overview.md)
- [Choosing a Pattern](../getting-started/choosing-a-pattern.md)
