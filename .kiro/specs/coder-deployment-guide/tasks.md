# Implementation Plan

## Phase 1: Project Setup and Core Infrastructure

- [x] 1. Initialize Terraform repository and project structure
  - [x] 1.1 Create Terraform repository with modular structure (vpc, eks, aurora, coder modules)
    - Set up S3 backend configuration for state management
    - Create production tfvars file
    - _Requirements: 2.6, 16.2_
  - [x] 1.2 Set up testing framework for IaC validation
    - Configure Terratest for Terraform modules
    - _Requirements: 16.4_
  - [x] 1.3 Configure coderd Terraform provider for Coder configuration
    - Set up provider for declarative Coder management (Day 1/2 operations)
    - Configure authentication and connection settings
    - Reference: https://registry.terraform.io/providers/coder/coderd/latest/docs
    - _Requirements: 16.3, 16.5_
  - [ ]* 1.4 Write property test for declarative configuration consistency
    - **Property 11: Declarative Configuration Consistency**
    - **Validates: Requirements 16.3**

- [x] 2. Implement VPC and networking module
  - [x] 2.1 Create VPC with calculated CIDR blocks for 3000 workspaces
    - Implement public subnets (3 AZs) for NAT Gateways and NLB
    - Implement private control subnets (3 AZs) for coderd nodes
    - Implement private provisioner subnets (3 AZs)
    - Implement private workspace subnets (3 AZs) with larger CIDR
    - Implement database subnets (3 AZs)
    - _Requirements: 2.1, 3.1b_
  - [x] 2.2 Configure NAT Gateways and routing tables
    - Deploy NAT Gateway per AZ for high availability
    - Configure route tables for private subnet egress
    - Configure DERP relay support via NAT Gateway and STUN
    - _Requirements: 3.1, 3.1a_
  - [x] 2.3 Create VPC endpoints for AWS services
    - S3, ECR, Secrets Manager, CloudWatch endpoints
    - _Requirements: 5.2_
  - [x] 2.4 Implement security groups
    - Node security group with NLB ingress and inter-node communication
    - RDS security group allowing 5432 from node SG
    - VPC endpoint security group
    - _Requirements: 2.1, 3.1_
  - [x] 2.5 Configure workspace egress filtering and internal resource access
    - Implement egress filtering for outbound internet traffic from workspaces
    - Configure access to on-premises resources and other AWS resources
    - _Requirements: 3.1d, 3.1e_
  - [ ]* 2.6 Write property test for infrastructure provisioning completeness
    - **Property 1: Infrastructure Provisioning Completeness**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4**

- [x] 3. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Phase 2: EKS Cluster and Node Groups

- [x] 4. Implement EKS cluster module
  - [x] 4.1 Create EKS cluster with managed control plane
    - Configure cluster logging and encryption
    - Set up OIDC provider for IRSA
    - _Requirements: 2.2_
  - [x] 4.2 Create coder-control node group (static scaling)
    - m5.large instances, min 2, max 3
    - Apply coder-control taint
    - _Requirements: 2.2, 4.1_
  - [x] 4.3 Create coder-prov node group (time-based scaling)
    - c5.2xlarge instances, min 0, max 20
    - Apply coder-prov taint
    - Configure scheduled scaling (0645/1815 ET) completing 15 min before target
    - _Requirements: 2.2, 4.2, 14.19_
  - [x] 4.4 Create coder-ws node group (time-based scaling)
    - m5.2xlarge instances, min 10, max 200
    - Apply coder-ws taint
    - Configure spot instances with on-demand fallback
    - Configure scheduled scaling (0645/1815 ET) completing 15 min before target
    - Configure pre-provisioning for morning usage
    - _Requirements: 2.2, 4.3, 5.1, 13.4, 14.18_
  - [ ]* 4.5 Write property test for static control plane configuration
    - **Property 4: Static Control Plane Configuration**
    - **Validates: Requirements 4.1**
  - [ ]* 4.6 Write property test for scheduled scaling pre-completion
    - **Property 14: Scheduled Scaling Pre-completion**
    - **Validates: Requirements 14.19**

- [x] 5. Implement Kubernetes controllers and namespaces
  - [x] 5.1 Deploy AWS Load Balancer Controller with IRSA
    - Create IAM role with least-privilege permissions
    - Deploy controller via Helm
    - _Requirements: 6.1_
  - [x] 5.2 Deploy EBS CSI driver with IRSA
    - Create IAM role for EBS operations
    - Configure storage classes with encryption
    - _Requirements: 6.1, 6.3_
  - [x] 5.3 Create namespaces for workload isolation
    - coder namespace for control plane
    - coder-prov namespace for provisioners
    - coder-ws namespace for workspaces
    - _Requirements: 6.6_

- [x] 6. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Phase 3: Database and Supporting Services

- [x] 7. Implement Aurora PostgreSQL module
  - [x] 7.1 Create Aurora Serverless v2 cluster
    - Multi-AZ deployment with automated failover
    - AES-256 encryption at rest
    - TLS for connections
    - _Requirements: 2.3, 12.9_
  - [x] 7.2 Configure automated backups for RPO compliance
    - Enable point-in-time recovery
    - Configure 90-day retention
    - Set up cross-region snapshot replication
    - _Requirements: 8.2, 8.4, 8.5, 8.7_
  - [x] 7.3 Configure database authentication
    - IAM authentication or Secrets Manager integration
    - _Requirements: 3.2_
  - [ ]* 7.4 Write property test for backup frequency RPO
    - **Property 5: Backup Frequency for RPO**
    - **Validates: Requirements 8.4**

- [x] 8. Implement DNS and certificate management
  - [x] 8.1 Configure Route 53 records
    - A/ALIAS record for ACCESS_URL pointing to NLB
    - Wildcard A/ALIAS record for WILDCARD_ACCESS_URL
    - Parameterize base domain as variable
    - _Requirements: 6.4, 6.5_
  - [x] 8.2 Configure ACM certificates
    - Request certificate for domain and wildcard
    - Configure automatic renewal
    - _Requirements: 3.3_
  - [ ]* 8.3 Write property test for DNS configuration completeness
    - **Property 12: DNS Configuration Completeness**
    - **Validates: Requirements 6.4**

- [x] 9. Implement Network Load Balancer
  - [x] 9.1 Create NLB with TLS termination
    - Configure ACM certificate attachment
    - Enforce TLS 1.2+ with approved cipher suites
    - _Requirements: 2.4, 12.7, 12.8, 12.8a_
  - [ ]* 9.2 Write property test for HTTPS enforcement
    - **Property 8: HTTPS Enforcement**
    - **Validates: Requirements 12.7, 12.8**

- [x] 10. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Phase 4: Observability and Logging

- [x] 11. Implement observability stack
  - [x] 11.1 Deploy Fluent Bit for log aggregation
    - Configure DaemonSet on all nodes
    - Forward container logs to CloudWatch Logs
    - Configure 90-day retention
    - _Requirements: 3.7, 3.8_
  - [x] 11.2 Configure CloudWatch Logs for Coder audit logs
    - Forward Coder audit logs to CloudWatch
    - Configure 90-day retention
    - _Requirements: 3.6, 3.8_
  - [x] 11.3 Enable VPC Flow Logs and CloudTrail
    - Configure VPC Flow Logs for security monitoring
    - Enable CloudTrail logging
    - _Requirements: 3.5_
  - [x] 11.4 Create CloudWatch dashboards and alerts
    - CPU, memory, database performance metrics
    - API latency monitoring (P95, P99)
    - Scaling delay alerts
    - _Requirements: 8.1, 14.13, 14.20_
  - [x] 11.5 Configure Coder observability Helm values
    - Prometheus metrics export (port 2112)
    - Optional AMP/CloudWatch Container Insights integration
    - _Requirements: 8.1a, 8.1b, 8.1c_

## Phase 5: Quota Validation and Pre-flight Checks

- [x] 12. Implement quota validation module
  - [x] 12.1 Create quota documentation
    - Document all required AWS service quotas
    - Include EC2, EBS, VPC, EKS, Aurora limits
    - _Requirements: 2a.1, 2a.2_
  - [x] 12.2 Implement quota check automation
    - Script to check current quotas vs required
    - Automation to request quota increases
    - _Requirements: 2a.3_
  - [x] 12.3 Implement pre-flight validation
    - Verify quota availability before provisioning
    - Block deployment if quotas insufficient
    - _Requirements: 2a.4, 2a.5_
  - [ ]* 12.4 Write property test for quota pre-flight validation
    - **Property 2: Quota Pre-flight Validation**
    - **Validates: Requirements 2a.4**

- [x] 13. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Phase 6: Coder Deployment

- [x] 14. Create Coder Helm values files
  - [x] 14.1 Create coder-values.yaml for coderd
    - Configure multiple replicas with health checks
    - Set resource limits
    - Configure OIDC authentication with any OIDC-capable IDP
    - Set internal provisioners to zero
    - Configure external auth for Git provider
    - _Requirements: 6.2, 11.1, 12.1, 12.5, 15.1_
  - [x] 14.2 Create coder-provisioner-values.yaml
    - Configure external provisioner deployment
    - Set provisioner key authentication
    - Configure node selector for coder-prov nodes
    - _Requirements: 11.1, 15.2_
  - [x] 14.3 Create observability-values.yaml
    - Configure Prometheus metrics
    - Set up Grafana dashboards
    - _Requirements: 15.2a_
  - [x] 14.4 Configure coderd provider Terraform module for Day 1/2 operations
    - Configure Coder internal quotas (max 3 workspaces per user)
    - Configure group sync settings
    - Configure organization settings
    - _Requirements: 14.15, 16.3_
  - [ ]* 14.5 Write property test for external provisioner configuration
    - **Property 6: External Provisioner Configuration**
    - **Validates: Requirements 11.1**

- [x] 15. Implement IAM roles for Coder components
  - [x] 15.1 Create CoderServerRole with IRSA
    - Secrets Manager access
    - RDS access
    - Least-privilege permissions
    - _Requirements: 2.5_
  - [x] 15.2 Create CoderProvRole with IRSA
    - EC2 provisioning permissions
    - EKS access for pod workspaces
    - IAM PassRole for workspace roles
    - _Requirements: 2.5_

- [x] 16. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Phase 7: RBAC and Authentication

- [x] 17. Implement RBAC configuration
  - [x] 17.1 Document role definitions and permissions
    - Owner role (2-3 individuals)
    - User Admin role
    - Template Admin role
    - Auditor role
    - Developer/Member role
    - _Requirements: 12a.1, 12a.2, 12a.3, 12a.4, 12a.5_
  - [x] 17.2 Configure IDP group synchronization via coderd provider
    - Use coderd_group resource to manage groups declaratively
    - Map coder-platform-admins to User Admin
    - Map coder-template-owners to Template Admin
    - Map coder-security-audit to Auditor
    - Map developers to Member
    - Configure automatic user provisioning via IDP sync
    - Configure user deprovisioning within 30 days of termination
    - _Requirements: 12c.1, 12c.4, 12c.5, 12c.6, 12c.7, 12c.9, 12c.10, 16.3_
  - [x] 17.3 Document segregation of duties enforcement
    - Template Admin and User Admin mutual exclusion
    - Privilege escalation prevention
    - _Requirements: 12a.7, 12a.8_
  - [x] 17.4 Document IDP authentication requirements
    - MFA enforcement at IDP level
    - Session expiration after 8 hours of inactivity
    - Account lockout after 5 failed attempts for 30 minutes
    - Concurrent session detection with security alerts
    - _Requirements: 12e.1_
  - [ ]* 17.5 Write property test for admin workspace access restriction
    - **Property 9: Admin Workspace Access Restriction**
    - **Validates: Requirements 12a.10**
  - [ ]* 17.6 Write property test for role segregation
    - **Property 16: Role Segregation**
    - **Validates: Requirements 12a.7**

- [x] 18. Implement provisioner key management
  - [x] 18.1 Create provisioner key rotation procedure
    - 90-day rotation schedule
    - 14-day expiration alerts
    - Key revocation procedure
    - _Requirements: 12f.1, 12f.2, 12f.3_
  - [x] 18.2 Configure provisioner scoping
    - Tag-based organization/template isolation
    - Access logging configuration
    - _Requirements: 12f.4, 12f.5, 12f.6_
  - [ ]* 18.3 Write property test for provisioner key rotation
    - **Property 15: Provisioner Key Rotation**
    - **Validates: Requirements 12f.2**

- [x] 19. Implement service account token management
  - [x] 19.1 Configure service account tokens for CI/CD
    - 90-day expiration
    - Template Admin scope only
    - Storage in Secrets Manager
    - Token compromise revocation procedure
    - _Requirements: 12d.3, 12d.6, 12d.7, 12d.8, 12d.9_
  - [x] 19.2 Document workspace access controls
    - Single owner per workspace (creator)
    - Workspace owners have full control
    - _Requirements: 12d.1, 12d.2_

- [x] 20. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Phase 8: Template Architecture - Two-Layer Toolchain + Infrastructure Base

Note: Requirements 11c, 11d, 11e, 11f, and 11g mandate a two-layer template architecture with portable toolchain templates and instance-specific infrastructure base modules. The current implementation has functional monolithic templates (pod-swdev, ec2-windev-gui, ec2-datasci) that need to be refactored into this two-layer architecture.

Current state: Monolithic templates exist in terraform/modules/coder/templates/ that combine toolchain and infrastructure concerns.
Target state: Separate toolchain templates (portable) + infrastructure base modules (instance-specific) with a composition mechanism.

- [x] 21. Define template contract and capability schema
  - [x] 21.1 Create template contract schema definition
    - Define contract inputs (workspace_name, owner, compute_profile, image_id)
    - Define contract outputs (agent_endpoint, env_vars, volume_mounts, metadata)
    - Define capability interface (persistent-home, network-egress, identity-mode, gpu-support, artifact-cache, secrets-injection)
    - _Requirements: 11d.1, 11d.2, 11d.3, 11d.4_
  - [x] 21.2 Create capability validation module
    - Implement contract validation logic for toolchain + base pairing
    - Create policy validation for controlled overrides
    - _Requirements: 11c.10, 11g.3_
  - [ ]* 21.3 Write property test for template contract satisfaction
    - **Property 14: Template Contract Satisfaction**
    - **Validates: Requirements 11c.10, 11d.1**

- [x] 22. Create toolchain templates (portable layer)
  - [x] 22.1 Create swdev-toolchain template
    - Create toolchain.yaml with Go 1.23, Node 22, Python 3.12
    - Declare tools: terraform, kubectl, gh, docker-cli
    - Declare capabilities: persistent-home, outbound-https, gui-vnc (optional)
    - Define compute profiles: SW Dev S/M/L, Platform/DevSecOps
    - Include bootstrap scripts and validation tests
    - _Requirements: 11.4, 11c.2, 11c.3, 11c.4, 11f.1, 11f.2_
  - [x] 22.2 Create windev-toolchain template
    - Create toolchain.yaml with C#, .NET 8
    - Declare tools: Visual Studio 2022, Git, Azure CLI, PowerShell
    - Declare capabilities: persistent-home, gui-rdp
    - Define compute profiles: SW Dev M/L
    - _Requirements: 11.4, 11c.2, 11c.3, 11c.4_
  - [x] 22.3 Create datasci-toolchain template
    - Create toolchain.yaml with Python 3.12, R 4.x
    - Declare tools: Jupyter Lab, CUDA toolkit
    - Declare libraries: PyTorch, TensorFlow, scikit-learn, pandas
    - Declare capabilities: persistent-home, outbound-https, gpu-support (optional)
    - Define compute profiles: Data Sci Standard/Large/XLarge
    - _Requirements: 11.4, 11c.2, 11c.3, 11c.4, 11.9_
  - [ ]* 22.4 Write property test for toolchain template portability
    - **Property 13: Toolchain Template Portability**
    - **Validates: Requirements 11c.2, 11g.1**

- [x] 23. Create infrastructure base modules (instance-specific layer)
  - [x] 23.1 Create base-k8s module
    - Implement Kubernetes pod workspace infrastructure
    - Configure namespace (coder-ws), node selector, PVC storage
    - Implement NetworkPolicy for workspace isolation
    - Configure service account with IRSA
    - Implement gui-vnc capability via KasmVNC sidecar
    - Support OS options: Amazon Linux 2023, Ubuntu 22.04/24.04
    - Auto-start/auto-stop enabled (0700/1800 ET)
    - _Requirements: 11.5, 11.6, 11.7, 11.8, 11a.1, 3.1c, 13.1, 13.2, 13.3_
  - [x] 23.2 Create base-ec2-linux module
    - Implement Linux EC2 workspace infrastructure
    - Configure hardened AMI selection (Amazon Linux 2023, Ubuntu 22.04/24.04)
    - Configure IAM instance role with least-privilege
    - Configure security groups for workspace isolation
    - Configure EBS gp3 for /home/coder persistence
    - Implement gui-vnc capability via KasmVNC
    - Auto-start/auto-stop enabled
    - _Requirements: 11.5, 11.6, 11.7, 11.8, 11a.1_
  - [x] 23.3 Create base-ec2-windows module
    - Implement Windows EC2 workspace infrastructure
    - Configure hardened Windows Server 2022 AMI
    - Configure NICE DCV (recommended) or WebRDP
    - Configure IAM instance role with least-privilege
    - Configure security groups for workspace isolation
    - Configure EBS gp3 for user data persistence
    - Auto-start/auto-stop enabled
    - _Requirements: 11.5, 11.6, 11.7_
  - [x] 23.4 Create base-ec2-gpu module
    - Implement GPU EC2 workspace infrastructure
    - Configure CUDA-enabled AMIs (Amazon Linux 2023, Ubuntu 22.04)
    - Support instance types: g4dn, g5, p3, p4d
    - Pre-install CUDA drivers and toolkit
    - Configure IAM instance role with least-privilege
    - Note: GPU nodes not pre-warmed, provisioning up to 5 min
    - Auto-start/auto-stop enabled
    - _Requirements: 11.5, 11.9, 14.7a_
  - [ ]* 23.5 Write property test for workspace network isolation
    - **Property 3: Workspace Network Isolation**
    - **Validates: Requirements 3.1c**
  - [ ]* 23.6 Write property test for template auto-stop configuration
    - **Property 7: Template Auto-Stop Configuration**
    - **Validates: Requirements 5.9**

- [x] 24. Implement template composition and resolution
  - [x] 24.1 Create template composition module
    - Implement toolchain + base + overrides composition logic
    - Record provenance (toolchain version, base version, artifact IDs)
    - Integrate with coderd provider for deployment
    - _Requirements: 11c.7, 11d.7_
  - [x] 24.2 Configure default template pairings
    - swdev-toolchain + base-k8s → pod-swdev
    - windev-toolchain + base-ec2-windows → ec2-windev-gui
    - datasci-toolchain + base-ec2-linux → ec2-datasci
    - datasci-toolchain + base-ec2-gpu → ec2-datasci-gpu
    - _Requirements: 11c.8_
  - [x] 24.3 Deploy composed templates via coderd provider
    - Use coderd_template resource for declarative template management
    - Configure template access permissions via coderd_template_acl
    - Manage template versions through Terraform
    - _Requirements: 16.3, 12b.3_
  - [ ]* 24.4 Write property test for template composition provenance
    - **Property 15: Template Composition Provenance**
    - **Validates: Requirements 11d.7**
  - [ ]* 24.5 Write property test for infrastructure base override validation
    - **Property 16: Infrastructure Base Override Validation**
    - **Validates: Requirements 11c.9, 11g.2, 11g.3**
  - [ ]* 24.6 Write property test for t-shirt size template availability
    - **Property 10: T-Shirt Size Template Availability**
    - **Validates: Requirements 14.16**

- [x] 25. Implement template governance CI/CD
  - [x] 25.1 Create toolchain template CI/CD pipeline
    - Git repository for toolchain templates (central catalog)
    - Lint and contract validation
    - Security scanning for dependencies
    - Approval gates for platform owner and security
    - Publish to central catalog
    - _Requirements: 11b.1, 11b.2, 11b.4, 11f.3, 11f.4_
  - [x] 25.2 Create infrastructure base CI/CD pipeline
    - Git repository for infrastructure bases (per instance)
    - Terraform validate and security scanning
    - Approval gates for platform owner
    - Publish to instance-scoped registry
    - _Requirements: 11b.1, 11b.3, 11b.5_
  - [x] 25.3 Configure upgrade channels
    - Implement stable, beta, pinned channels for infrastructure bases
    - Document upgrade procedures
    - _Requirements: 11e.3_
  - [x] 25.4 Document template access control and lifecycle
    - Templates organized by team/project/environment
    - Default visibility set to private
    - Access granted to groups, not individuals
    - Template deprecation and archival procedures
    - CVE response ownership (toolchain layer vs infra layer)
    - _Requirements: 12b.1, 12b.2, 12b.3, 12b.6, 12b.7, 11b.8, 11b.9_
  - [ ]* 25.5 Write property test for toolchain template semantic versioning
    - **Property 17: Toolchain Template Semantic Versioning**
    - **Validates: Requirements 11d.5, 11b.8**

- [x] 26. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Phase 9: Documentation

Note: Several documentation files already exist in terraform/docs/ covering RBAC, provisioner key management, service account tokens, security controls, and IDP configuration.

- [x] 27. Create security and operational documentation
  - [x] 27.1 Document RBAC configuration
    - Role definitions (Owner, User Admin, Template Admin, Auditor, Member)
    - Permission matrix
    - IDP group mappings
    - Segregation of duties enforcement
    - IDP authentication requirements (MFA, session management, lockout)
    - _Requirements: 12a.1-12a.10, 12c.1-12c.10, 12e.1_
  - [x] 27.2 Document provisioner key management
    - 90-day rotation schedule
    - 14-day expiration alerts
    - Key revocation procedure
    - Provisioner scoping with tags
    - Access logging configuration
    - _Requirements: 12f.1-12f.6_
  - [x] 27.3 Document service account token management
    - CI/CD authentication configuration
    - 90-day token expiration
    - Template Admin scope only
    - Secrets Manager storage
    - Token compromise response procedure
    - _Requirements: 12d.1-12d.9_
  - [x] 27.4 Document security controls
    - TLS configuration
    - Encryption at rest
    - Network isolation
    - _Requirements: 12.7, 12.8, 12.9_
  - [x] 27.5 Document IDP configuration guide
    - OIDC setup
    - Group sync configuration
    - _Requirements: 12.1, 12.2, 12.3_

- [x] 28. Create deployment guide documentation
  - [x] 28.1 Write architecture overview section
    - High-level architecture diagram (AWS Architecture Icons)
    - Network architecture diagram
    - Security architecture diagram
    - EKS cluster architecture diagram
    - Data flow diagram
    - DR/HA architecture diagram
    - Template architecture diagram (toolchain + infrastructure base layers)
    - _Requirements: 1.1, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_
  - [x] 28.2 Write prerequisites and quota requirements section
    - AWS CLI, Terraform, kubectl configuration
    - Service quota requirements
    - Coder Premium license requirements
    - All users must be licensed
    - _Requirements: 7.1, 2a.1, 17.1, 17.2, 17.3, 17.4_
  - [x] 28.3 Write step-by-step deployment procedures
    - Infrastructure deployment with validation commands
    - Coder configuration with Helm values
    - Template composition and deployment procedures
    - Post-deployment smoke tests
    - Target audience: DevSecOps Engineers L1-5, SysAdmins L3-L6
    - _Requirements: 7.2, 7.3, 7.4, 15.4a_
  - [x] 28.4 Write operational runbooks
    - Platform restore procedures
    - Upgrade procedures (infrastructure bases and toolchain templates)
    - Scaling procedures
    - Monthly backup restore testing procedures
    - _Requirements: 8.6, 8.8, 8.9, 8.10_
  - [x] 28.5 Write troubleshooting guide
    - Common error scenarios and resolutions
    - Template composition troubleshooting
    - _Requirements: 7.5_
  - [x] 28.6 Add documentation links
    - AWS EKS, Aurora, VPC, NLB, Route 53 links
    - Coder Helm, provisioner, template documentation links
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_
  - [x] 28.7 Document external system integrations
    - Git provider integration configuration
    - CI/CD integration for template deployment
    - Coder external authentication for workspace access to external services
    - _Requirements: 12g.1, 12g.2, 12g.6_

- [x] 29. Create Terraform repository documentation
  - [x] 29.1 Write README with quick start
    - Include Day 0 (infrastructure), Day 1 (initial config), Day 2 (ongoing management) workflows
    - Document template architecture (toolchain + infrastructure base)
    - _Requirements: 16.4, 16.5_
  - [x] 29.2 Write configuration reference
    - Document all parameterization options for AWS provider modules
    - Document coderd provider resources and data sources
    - Document template contract schema and capability interface
    - _Requirements: 15.4, 15.5, 11d.1_
  - [x] 29.3 Create example configurations
    - Production tfvars with customization examples
    - Example coderd provider configurations
    - Example toolchain template and infrastructure base pairings
    - _Requirements: 16.4_

- [x] 30. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Phase 10: Scale Testing and Performance Validation

- [x] 31. Configure Coder scale testing utilities
  - [x] 31.1 Create scale test configuration file
    - Configure `coder scaletest create-workspaces` for 1000 concurrent workspaces
    - Configure `coder scaletest dashboard` for API latency testing
    - Configure `coder scaletest workspace-traffic` for network throughput
    - _Requirements: 14.11, 14.9, 14.10_
  - [x] 31.2 Document scale test procedures
    - Pre-production scale validation runbook
    - Performance acceptance criteria (P95 <500ms, P99 <1s)
    - Workspace provisioning targets (pod <2min, EC2 <5min)
    - _Requirements: 14.6, 14.7, 14.9, 14.10, 14.11_

- [ ] 32. Implement performance validation tests
  - [ ]* 32.1 Write property test for workspace provisioning time
    - **Property 18: Workspace Provisioning Time**
    - Pod workspaces < 2 min, EC2 workspaces < 5 min
    - **Validates: Requirements 14.6, 14.7**
  - [ ]* 32.2 Write property test for group sync propagation
    - **Property 19: Group Sync Propagation**
    - **Validates: Requirements 12c.2**
  - [ ]* 32.3 Write property test for API latency
    - Verify P95 < 500ms, P99 < 1s under load
    - **Validates: Requirements 14.9, 14.10**

- [x] 33. Execute scale validation (pre-production)
  - [x] 33.1 Run workspace creation scale test
    - Execute `coder scaletest create-workspaces --count 1000`
    - Verify concurrent provisioning capacity
    - _Requirements: 14.11_
  - [x] 33.2 Run API latency scale test
    - Execute `coder scaletest dashboard`
    - Verify P95 <500ms, P99 <1s under load
    - _Requirements: 14.9, 14.10_
  - [x] 33.3 Run workspace traffic test
    - Execute `coder scaletest workspace-traffic`
    - Verify network throughput meets requirements
    - _Requirements: 14.6, 14.7_

- [x] 34. Final Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
