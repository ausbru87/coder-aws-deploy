# Prerequisites and Quota Requirements

This document outlines the tools, AWS configurations, service quotas, licenses, identity provider requirements, and DNS/certificate prerequisites needed before deploying the Coder platform on AWS EKS.

**Target Audience:** DevSecOps Engineers L1-5, SysAdmins L3-L6

## Table of Contents

1. [Required Tools](#required-tools)
2. [AWS Account Configuration](#aws-account-configuration)
3. [AWS Service Quotas](#aws-service-quotas)
4. [Coder License Requirements](#coder-license-requirements)
5. [Identity Provider Requirements](#identity-provider-requirements)
6. [DNS and Certificate Requirements](#dns-and-certificate-requirements)

## Required Tools

Before deploying, ensure the following tools are installed and configured:

| Tool | Minimum Version | Purpose | Installation |
|------|-----------------|---------|--------------|
| AWS CLI | 2.x | AWS resource management | [AWS CLI Install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Terraform | 1.5.0+ | Infrastructure provisioning | [Terraform Install](https://developer.hashicorp.com/terraform/install) |
| kubectl | 1.28+ | Kubernetes management | [kubectl Install](https://kubernetes.io/docs/tasks/tools/) |
| Helm | 3.0+ | Chart deployments | [Helm Install](https://helm.sh/docs/intro/install/) |
| jq | 1.6+ | JSON processing | `brew install jq` or package manager |

### Verify Installations

```bash
# Check AWS CLI
aws --version
aws sts get-caller-identity

# Check Terraform
terraform version

# Check kubectl
kubectl version --client

# Check Helm
helm version
```

## AWS Account Configuration

### Required IAM Permissions

The deploying user/role needs the following permissions:
- `AdministratorAccess` (recommended for initial deployment)
- Or a custom policy with permissions for: VPC, EKS, EC2, RDS, IAM, Route53, ACM, Secrets Manager, CloudWatch, S3

### Configure AWS CLI

```bash
# Configure credentials
aws configure

# Or use SSO
aws sso login --profile your-profile

# Verify access
aws sts get-caller-identity
```

## AWS Service Quotas

The following service quotas must be available before deployment. The quota validation module will check these automatically.

### EC2 Quotas

| Quota | Service Code | Quota Code | Required Value | Purpose |
|-------|--------------|------------|----------------|---------|
| Running On-Demand Standard instances | ec2 | L-1216C47A | 800 vCPUs | Control + provisioner nodes |
| Running Spot Standard instances | ec2 | L-34B43A08 | 1600 vCPUs | Workspace nodes |
| Running On-Demand G and VT instances | ec2 | L-DB2E81BA | 64 vCPUs | GPU workspaces |
| Running On-Demand P instances | ec2 | L-417A185B | 32 vCPUs | Large ML workspaces |

### EBS Quotas

| Quota | Service Code | Quota Code | Required Value | Purpose |
|-------|--------------|------------|----------------|---------|
| General Purpose SSD (gp3) volume storage | ebs | L-7A658B76 | 50 TiB | Workspace storage |
| Provisioned IOPS SSD (io1) volume storage | ebs | L-FD252861 | 10 TiB | Database storage |

### VPC Quotas

| Quota | Service Code | Quota Code | Required Value | Purpose |
|-------|--------------|------------|----------------|---------|
| VPCs per Region | vpc | L-F678F1CE | 5 | Platform VPC |
| NAT gateways per Availability Zone | vpc | L-FE5A380F | 3 | HA NAT configuration |
| Elastic IPs per Region | ec2 | L-0263D0A3 | 10 | NAT Gateway EIPs |

### EKS Quotas

| Quota | Service Code | Quota Code | Required Value | Purpose |
|-------|--------------|------------|----------------|---------|
| Clusters | eks | L-1194D53C | 5 | Coder cluster |
| Managed node groups per cluster | eks | L-6D54EA21 | 10 | Node groups |
| Nodes per managed node group | eks | L-BD136A63 | 200 | Workspace nodes |

### RDS Quotas

| Quota | Service Code | Quota Code | Required Value | Purpose |
|-------|--------------|------------|----------------|---------|
| DB clusters | rds | L-952B80B8 | 10 | Aurora cluster |
| Total storage for all DB instances | rds | L-7B6409FD | 100 GB | Database storage |

### Check Current Quotas

```bash
# Run the quota check script
./terraform/modules/quota-validation/scripts/check-quotas.sh

# Or check individual quotas
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A
```

### Request Quota Increases

```bash
# Use the automated script
./terraform/modules/quota-validation/scripts/request-quota-increases.sh

# Or request manually via AWS Console
# Service Quotas → Select service → Request quota increase
```

## Coder License Requirements

### License Type

**License Tier:** Coder Premium

| Requirement | Details |
|-------------|---------|
| License Tier | Premium (required for prebuilds and enterprise features) |
| User Licensing | All users accessing the platform must be licensed |
| Support Level | Premium support included |

### License Features Required

- External provisioners
- High availability
- Audit logging
- OIDC authentication
- Group sync
- Workspace quotas
- Template ACLs

### Obtain License

1. Contact Coder sales: https://coder.com/contact
2. Provide expected user count and workspace requirements
3. License key will be provided for deployment

### Configure License

```yaml
# In coder-values.yaml
coder:
  env:
    - name: CODER_LICENSE
      valueFrom:
        secretKeyRef:
          name: coder-license
          key: license
```

## Identity Provider Requirements

An OIDC-capable identity provider must be configured before deployment.

### Supported IDPs

- Microsoft Entra ID (Azure AD)
- Okta
- Google Workspace
- Auth0
- Keycloak
- Any OIDC-compliant provider

### Required IDP Capabilities

| Capability | Requirement |
|------------|-------------|
| MFA Enforcement | Required for all users |
| Session Expiration | 8 hours of inactivity |
| Account Lockout | 5 failed attempts, 30 min lockout |
| Group Claims | Groups in ID token |
| Concurrent Session Detection | Alert on multiple locations |

### Required IDP Groups

| IDP Group | Coder Role | Purpose |
|-----------|------------|---------|
| `coder-platform-admins` | User Admin | User lifecycle management |
| `coder-template-owners` | Template Admin | Template management |
| `coder-security-audit` | Auditor | Security monitoring |
| `developers` | Member | Standard developer access |

### IDP Configuration

See [IDP Configuration Guide](../../terraform/docs/idp-configuration-guide.md) for detailed setup instructions.

## DNS and Certificate Requirements

### Domain Requirements

- Base domain owned and managed in Route 53
- Ability to create A/ALIAS records
- Wildcard subdomain support

### Certificate Requirements

- ACM certificate for `coder.yourdomain.com`
- ACM certificate for `*.coder.yourdomain.com` (wildcard)
- Certificates must be in the deployment region

### Request ACM Certificate

```bash
# Request certificate with wildcard
aws acm request-certificate \
  --domain-name coder.example.com \
  --subject-alternative-names "*.coder.example.com" \
  --validation-method DNS \
  --region us-east-1

# Validate via DNS (add CNAME records to Route 53)
# Certificate ARN will be used in deployment
```

## Next Steps

Once all prerequisites are satisfied, proceed to:
1. [Architecture Overview](overview.md) - Review the system architecture
2. [Day 0: Infrastructure Deployment](../operations/day0-deployment.md) - Begin deployment

## Related Documentation

- [Architecture Overview](overview.md)
- [Day 0: Infrastructure Deployment](../operations/day0-deployment.md)
- [IDP Configuration Guide](../../terraform/docs/idp-configuration-guide.md)
- [RBAC Configuration](../../terraform/docs/rbac-configuration.md)

---

*Document Version: 1.0*
*Last Updated: December 2024*
*Maintained by: Platform Engineering Team*
