# Requirements Document

## Introduction

This document defines the requirements for creating a comprehensive deployment guide and Infrastructure as Code (IaC) solution for a production-ready Coder development environment on Amazon EKS. The solution will enable organizations to deploy a highly available, secure, and cost-optimized Coder platform following AWS Well-Architected principles.

## Glossary

- **Coder Platform**: The complete Coder development environment including control plane, provisioners, and workspace infrastructure
- **Deployment Guide**: Comprehensive documentation covering architecture, prerequisites, deployment steps, and operational procedures
- **IaC Solution**: Terraform modules and configuration files that provision the complete infrastructure
- **Control Plane**: The core Coder services (coderd) that manage user authentication, workspace orchestration, and API endpoints
- **Provisioner Nodes**: Dedicated compute resources for running Terraform operations and workspace provisioning
- **Workspace Nodes**: Compute resources where developer workspaces execute
- **Aurora Cluster**: Amazon Aurora PostgreSQL database cluster providing persistent storage for Coder metadata
- **NLB**: Network Load Balancer providing high-availability ingress for user traffic
- **IRSA**: IAM Roles for Service Accounts providing secure AWS API access to Kubernetes workloads
- **Toolchain Template**: A portable, infrastructure-agnostic template that declares what a workspace should be (languages, tools, dependencies, capabilities) without specifying how it runs
- **Infrastructure Base Module**: An instance-specific module that defines how workspaces run in a given Coder instance (compute, networking, storage, identity) and implements capability contracts
- **Template Contract**: The stable interface between toolchain templates and infrastructure base modules defining inputs, outputs, and capability requirements
- **Capability**: A workspace feature requested by toolchain templates and implemented by infrastructure bases (e.g., persistent home, GPU support, network egress policy)
- **Toolchain Manifest**: A declarative file (toolchain.yaml) in a toolchain template that specifies languages, tools, versions, and required capabilities
- **Template Composition**: The process of combining a toolchain template with an infrastructure base to produce a runnable workspace template
- **SBOM**: Software Bill of Materials - a formal record of components used in building software artifacts for security and compliance tracking

## Requirements

### Requirement 1

**User Story:** As a platform engineer, I want a complete deployment guide with architectural diagrams, so that I can understand the system design and deployment approach before implementation.

#### Acceptance Criteria

1. WHEN the deployment guide is accessed THEN the system SHALL provide the following architectural diagrams:
   - High-Level Architecture diagram showing overall solution with AWS services and data flows
   - Network Architecture diagram showing VPC, subnets, security groups, and connectivity
   - Security Architecture diagram showing IAM roles, IRSA, encryption boundaries, and access controls
   - EKS Cluster Architecture diagram showing node groups, namespaces, and workload placement
   - Data Flow diagram showing user request flow from client through NLB to workspaces
   - DR/HA Architecture diagram showing failover paths, multi-AZ deployment, and recovery flows
2. WHEN reviewing the architecture THEN the system SHALL document all AWS services, their relationships, and security boundaries
3. WHEN examining network design THEN the system SHALL specify VPC CIDR blocks, subnet allocation, and routing configurations
4. WHEN analyzing security THEN the system SHALL detail IAM roles, security groups, and TLS certificate management
5. WHEN reviewing high availability THEN the system SHALL document multi-AZ deployment patterns and failover mechanisms

### Requirement 2

**User Story:** As a DevOps engineer, I want modular Terraform code that provisions the complete infrastructure, so that I can deploy and manage the Coder platform using Infrastructure as Code principles.

#### Acceptance Criteria

1. WHEN executing Terraform modules THEN the system SHALL provision VPC, subnets, NAT gateways, and security groups according to the network design
2. WHEN creating the EKS cluster THEN the system SHALL configure three distinct node groups for control plane, provisioners, and workspaces with appropriate taints and labels
3. WHEN provisioning Aurora THEN the system SHALL create a multi-AZ PostgreSQL Serverless v2 cluster with automated backups and encryption
4. WHEN configuring load balancing THEN the system SHALL deploy a Network Load Balancer with ACM certificates for TLS termination
5. WHEN setting up IAM THEN the system SHALL create least-privilege roles for Coder services, provisioners, and AWS controllers using IRSA
6. WHEN managing Terraform state THEN the system SHALL store state centrally in S3 with appropriate locking
7. WHEN approving infrastructure changes THEN platform owners SHALL approve all infrastructure modifications

### Requirement 2a

**User Story:** As a platform engineer, I want documentation and automation for AWS service quotas, so that I can ensure the deployment has sufficient limits before provisioning.

#### Acceptance Criteria

1. WHEN documenting prerequisites THEN the Deployment Guide SHALL list all AWS service quotas and limits required for the deployment
2. WHEN specifying quotas THEN the documentation SHALL define the required values for EC2 instances, EBS volumes, VPC resources, EKS node limits, and Aurora capacity
3. WHEN automating quota requests THEN the IaC SHALL include automation to check current quotas and request increases where necessary
4. WHEN validating deployment readiness THEN the IaC SHALL include pre-flight checks to verify quota availability before provisioning
5. WHEN calculating quota requirements THEN the system SHALL base calculations on maximum capacity of 3000 concurrent workspaces plus infrastructure overhead

### Requirement 2b

**User Story:** As a platform engineer, I want all software components to use the latest stable releases, so that the deployment benefits from security patches, bug fixes, and new features.

#### Acceptance Criteria

1. WHEN specifying Terraform core version THEN the IaC SHALL use the latest stable release available at deployment time
2. WHEN specifying Terraform provider versions THEN the IaC SHALL use the latest stable releases for all providers (AWS, Kubernetes, Helm, coderd, TLS, Random)
3. WHEN specifying EKS cluster version THEN the IaC SHALL use the latest stable Kubernetes version supported by Amazon EKS
4. WHEN specifying Aurora PostgreSQL version THEN the IaC SHALL use the latest stable PostgreSQL version supported by Aurora Serverless v2
5. WHEN specifying Coder Helm chart version THEN the IaC SHALL use the latest stable Coder release
6. WHEN documenting versions THEN the Deployment Guide SHALL include a version matrix listing all software components and their minimum required versions
7. WHEN updating versions THEN the IaC SHALL support version updates through variable configuration without code changes

### Requirement 3

**User Story:** As a security engineer, I want the deployment to follow security best practices, so that the Coder platform meets enterprise security requirements.

#### Acceptance Criteria

1. WHEN network traffic flows THEN the system SHALL enforce private subnet isolation with NAT gateway egress and VPC endpoints for AWS services
1a. WHEN users access workspaces THEN the system SHALL support DERP relay inside coderd via NAT Gateway and direct connection through STUN
1b. WHEN sizing IP address allocation THEN the system SHALL calculate CIDR blocks based on maximum number of nodes and workspaces for both private and public subnets
1c. WHEN isolating workspaces THEN each workspace template SHALL include NetworkPolicy configurations to isolate workspaces from each other
1d. WHEN controlling workspace egress THEN the system SHALL filter outbound internet traffic from workspaces
1e. WHEN accessing internal resources THEN workspaces SHALL be able to access both on-premises resources and other AWS resources
2. WHEN accessing the database THEN the system SHALL use IAM authentication or AWS Secrets Manager for credential management
3. WHEN handling TLS THEN the system SHALL terminate SSL at the load balancer using ACM certificates with automatic renewal
4. WHEN managing secrets THEN the system SHALL integrate with AWS Secrets Manager or Parameter Store for sensitive configuration
5. WHEN auditing access THEN the system SHALL enable CloudTrail logging and VPC Flow Logs for security monitoring
6. WHEN capturing Coder audit logs THEN the system SHALL forward all Coder audit logs to Amazon CloudWatch Logs
7. WHEN configuring log forwarding THEN the system SHALL use Fluent Bit or CloudWatch agent to capture and export all container logs from EKS to CloudWatch Logs
8. WHEN retaining audit logs THEN the system SHALL configure CloudWatch Logs retention for 90 days minimum

### Requirement 4

**User Story:** As a site reliability engineer, I want automated scaling and high availability features, so that the platform can handle variable workloads and maintain uptime during failures.

#### Acceptance Criteria

1. WHILE the Coder platform is operational THEN the system SHALL maintain a static coderd deployment that does not scale up or down
2. WHEN provisioner capacity is managed THEN the system SHALL scale provisioner nodes and pods using time-based schedules aligned with work hours
3. WHEN workspace capacity is managed THEN the system SHALL scale workspace nodes using time-based schedules aligned with work hours
4. WHEN configuring autoscaling THEN the system SHALL use time-based scaling policies exclusively and SHALL NOT use event-based or demand-based scaling triggers
5. WHEN an availability zone fails THEN the system SHALL maintain service availability through multi-AZ deployment of control plane and database
6. WHEN nodes experience spot interruption THEN the system SHALL gracefully handle workspace migration and node replacement
7. WHEN database failover occurs THEN the system SHALL automatically reconnect Coder services to the new primary instance
8. WHEN considering data residency THEN the system SHALL have no data sovereignty requirements restricting data to specific regions
8b. WHEN using cross-region features THEN no AWS services SHALL be prohibited from using cross-region capabilities
8c. WHEN selecting deployment region THEN the system SHALL optimize for users located in the United States East Coast (NY, VA, MD, PA as the example)
8d. WHEN storing backups THEN backups MAY be stored in a different region than the primary deployment
9. WHEN measuring availability THEN the system SHALL target 99.9% uptime (three nines) for the Coder control plane
10. WHEN experiencing infrastructure failures THEN the system SHALL remain operational during single availability zone failures
11. WHEN performing planned maintenance THEN the system SHALL tolerate up to 90 minutes downtime window with zero downtime as the preferred target
12. WHEN scaling events occur THEN the system SHALL cause no disruption to active users with established workspace connections

### Requirement 5

**User Story:** As a cost optimization specialist, I want the deployment to include cost control mechanisms, so that the platform operates efficiently within budget constraints.

#### Acceptance Criteria

1. WHEN provisioning compute resources THEN the system SHALL use spot instances for workspace nodes with on-demand fallback for critical workloads
2. WHEN handling AWS API traffic THEN the system SHALL deploy VPC endpoints for S3, ECR, and other high-traffic services to reduce NAT charges
3. WHEN scaling during off-hours THEN the system SHALL implement scheduled scaling policies to reduce provisioner capacity outside business hours
4. WHEN monitoring costs THEN the system SHALL include resource tagging strategy for cost allocation and tracking
5. WHEN rightsizing resources THEN the system SHALL provide monitoring and alerting for resource utilization optimization
6. WHEN allocating costs THEN all platform costs SHALL be shared at the platform level without per-team or per-department attribution
7. WHEN balancing cost and availability THEN availability SHALL be prioritized without fully sacrificing cost-optimization measures
8. WHEN setting budget constraints THEN specific monthly budget and per-user cost targets SHALL be determined by the customer based on their requirements
9. WHEN configuring workspace templates THEN all templates SHALL have auto-start and auto-stop enabled and configured by default
10. WHEN requiring 24x7 workspaces THEN only specially designated instances SHALL be permitted to run continuously without auto-stop
11. WHEN controlling resource consumption THEN the system SHALL enable Coder internal quotas to limit workspace resource usage per user or group

### Requirement 6

**User Story:** As a Kubernetes administrator, I want the deployment to include all necessary Kubernetes controllers and configurations, so that the platform integrates properly with EKS and AWS services.

#### Acceptance Criteria

1. WHEN deploying Kubernetes controllers THEN the system SHALL install AWS Load Balancer Controller and EBS CSI driver with proper IRSA configurations
2. WHEN configuring Coder services THEN the system SHALL deploy coderd with multiple replicas, health checks, and proper resource limits
3. WHEN managing storage THEN the system SHALL configure EBS CSI for persistent volumes with appropriate storage classes and encryption
4. WHEN handling DNS THEN the system SHALL assume Route 53 owns the base domain and configure records for coder ACCESS_URL and WILDCARD_ACCESS_URL
5. WHEN parameterizing DNS THEN the IaC SHALL accept the base domain as a variable and automatically configure the coder subdomain and wildcard records
6. WHEN organizing workloads THEN the system SHALL create separate namespaces for Coder control plane, provisioners, workspaces, and system components

### Requirement 7

**User Story:** As a deployment operator, I want step-by-step deployment procedures with validation steps, so that I can successfully deploy and verify the Coder platform.

#### Acceptance Criteria

1. WHEN following deployment steps THEN the system SHALL provide prerequisite validation including AWS CLI, Terraform, and kubectl configuration
2. WHEN executing infrastructure deployment THEN the system SHALL include validation commands to verify each component's successful provisioning
3. WHEN configuring Coder THEN the system SHALL provide Helm values and configuration templates for production deployment
4. WHEN testing the deployment THEN the system SHALL include smoke tests for authentication, workspace creation, and basic functionality
5. WHEN troubleshooting issues THEN the system SHALL provide common error scenarios and resolution procedures

### Requirement 8

**User Story:** As a system administrator, I want operational procedures and monitoring setup, so that I can maintain the Coder platform in production.

#### Acceptance Criteria

1. WHEN monitoring system health THEN the system SHALL provide CloudWatch dashboards and alerts for key metrics including CPU, memory, and database performance
1a. WHEN deploying observability THEN the system SHALL install and configure the Coder observability stack including Prometheus metrics
1b. WHERE AWS observability integration is required THEN the system SHALL connect Coder Prometheus metrics to Amazon Managed Service for Prometheus (AMP) or CloudWatch Container Insights
1c. WHERE AWS observability integration is required THEN the system SHALL provide Amazon Managed Grafana dashboards or CloudWatch dashboards for Coder-specific metrics
2. WHEN performing backups THEN the system SHALL configure Aurora automated backups with point-in-time recovery enabled
3. WHEN defining recovery objectives THEN the system SHALL target a Recovery Time Objective (RTO) of 2 hours maximum
4. WHEN defining recovery objectives THEN the system SHALL target a Recovery Point Objective (RPO) of 15 minutes maximum
5. WHEN retaining backups THEN the system SHALL retain Aurora backups for 90 days minimum for compliance requirements
6. WHEN validating disaster recovery THEN the system SHALL document procedures for monthly backup restore testing
7. WHEN protecting against regional failures THEN the system SHALL configure cross-region backup replication for Aurora snapshots
8. WHEN documenting DR procedures THEN the Deployment Guide SHALL include platform restore runbooks
8a. WHEN backing up workspace data THEN the system SHALL NOT backup individual workspace contents as platform DB backup is sufficient
8b. WHEN defining data ownership THEN workspace data SHALL be per-user owned with the organization retaining ultimate ownership
8c. WHEN determining workspace persistence THEN persistence requirements SHALL be controlled via template definitions
8d. WHEN following best practices THEN workspaces SHALL be treated as ephemeral with code stored in Git and data in external systems
9. WHEN updating the platform THEN the system SHALL provide upgrade procedures for Coder, Kubernetes, and infrastructure components
10. WHEN scaling the platform THEN the system SHALL document procedures for adding capacity and modifying node group configurations

### Requirement 9

**User Story:** As a deployment operator, I want each deployment step to include links to official Coder and AWS documentation, so that I can reference authoritative sources for deeper understanding and troubleshooting.

#### Acceptance Criteria

1. WHEN documenting EKS cluster setup THEN the Deployment Guide SHALL include links to AWS EKS documentation for cluster creation, node groups, and managed add-ons
2. WHEN documenting Aurora PostgreSQL configuration THEN the Deployment Guide SHALL include links to AWS Aurora documentation for Serverless v2, IAM authentication, and backup procedures
3. WHEN documenting Coder installation THEN the Deployment Guide SHALL include links to Coder documentation for Helm chart configuration, external database setup, and provisioner configuration
4. WHEN documenting networking components THEN the Deployment Guide SHALL include links to AWS VPC, NLB, and Route 53 documentation for subnet design, load balancer configuration, and DNS management
5. WHEN documenting Kubernetes controllers THEN the Deployment Guide SHALL include links to AWS Load Balancer Controller and EBS CSI driver documentation for installation and configuration
6. WHEN documenting security configurations THEN the Deployment Guide SHALL include links to AWS IAM, IRSA, and ACM documentation alongside Coder security best practices documentation
7. WHEN documenting workspace templates THEN the Deployment Guide SHALL include links to Coder template documentation, registry.coder.com, and relevant Terraform provider documentation for Kubernetes and EC2 workspace configurations

### Requirement 10

**User Story:** As a solutions architect, I want architectural and deployment diagrams that follow AWS diagramming standards, so that the documentation is professional, consistent, and easily understood by AWS-familiar teams.

#### Acceptance Criteria

1. WHEN creating architectural diagrams THEN the Deployment Guide SHALL use official AWS Architecture Icons from the AWS Architecture Icons asset package
2. WHEN depicting AWS services THEN the Deployment Guide SHALL follow AWS Architecture Center diagram conventions for service representation and grouping
3. WHEN illustrating network topology THEN the Deployment Guide SHALL use standard AWS VPC, subnet, and availability zone visual representations
4. WHEN showing data flows THEN the Deployment Guide SHALL use consistent arrow styles and color coding per AWS diagramming best practices
5. WHEN grouping resources THEN the Deployment Guide SHALL use AWS-standard boundary boxes for regions, VPCs, availability zones, and security groups
6. WHEN labeling components THEN the Deployment Guide SHALL include service names, instance types, and key configuration details following AWS naming conventions

### Requirement 11

**User Story:** As a platform engineer, I want Coder configured with external provisioners and proper component isolation, so that the platform scales efficiently and maintains separation of concerns.

#### Acceptance Criteria

1. WHEN configuring Coder provisioners THEN the system SHALL set internal provisioners to zero and deploy external provisioners as a separate Helm chart deployment in EKS
2. WHEN deploying Coder components THEN the system SHALL place coderd, provisionerd, and workspaces on separate EKS nodepools for isolation and independent scaling
3. WHEN configuring workspace templates THEN the system SHALL support both EC2-based workspaces and EKS pod-based workspaces
4. WHEN deploying initial toolchain templates THEN the system SHALL include the following portable toolchain templates:
   - swdev-toolchain: Software development toolchain template with language/tool declarations and capability requirements
   - windev-toolchain: Windows development toolchain template with Visual Studio and common dev tool declarations
   - datasci-toolchain: Data science toolchain template with ML tooling, GPU capability requirements, and Jupyter declarations
5. WHEN deploying initial base modules THEN the system SHALL include the following infrastructure base modules:
   - base-k8s: Kubernetes pod-based workspace infrastructure module for EKS
   - base-ec2-linux: EC2-based Linux workspace infrastructure module
   - base-ec2-windows: EC2-based Windows workspace infrastructure module with DCV or WebRDP
   - base-ec2-gpu: EC2-based GPU workspace infrastructure module for ML workloads
6. WHEN configuring GUI-based workspaces THEN the system SHALL support Windows workspaces using EC2 with DCV or WebRDP, and Linux workspaces using KasmVNC in an EKS-pod or EC2
7. WHEN configuring GUI-based workspaces THEN the system SHALL support Windows, Amazon Linux, and Ubuntu operating systems
8. WHEN configuring headless workspaces THEN the system SHALL support non-GUI Linux workspaces on Amazon Linux and Ubuntu
9. WHEN configuring data science workspaces THEN the system SHALL support GPU instance types (g4dn, g5, p3, p4d) and pre-installed ML tooling (Jupyter, Python, CUDA)

### Requirement 11a

**User Story:** As a developer, I want workspaces with proper persistence and customization options, so that my development environment is consistent and personalized.

#### Acceptance Criteria

1. WHEN persisting workspace data THEN the system SHALL persist the user's /home/coder directory across workspace restarts
2. WHEN customizing workspaces THEN users SHALL have minimal ability to customize their workspace environment
3. WHEN restricting customization THEN users SHALL NOT be able to modify base workspace images or core configurations

### Requirement 11c

**User Story:** As a platform engineer, I want a two-layer template architecture with portable toolchain templates and instance-specific infrastructure base modules, so that templates are portable across Coder instances while infrastructure concerns remain instance-owned.

#### Acceptance Criteria

1. WHEN designing template architecture THEN the system SHALL separate templates into two layers: Toolchain Layer (portable) and Infrastructure Base Layer (instance-specific)
2. WHEN creating toolchain templates THEN the toolchain template SHALL declare toolchains, languages, libraries, and required capabilities without infrastructure-specific details
3. WHEN creating toolchain templates THEN the toolchain template SHALL include a toolchain manifest (toolchain.yaml) declaring tools, versions, and capability requirements
4. WHEN defining capabilities THEN the toolchain template SHALL request capabilities including compute profile, network egress policy, persistent home support, identity mode, artifact cache support, and secrets injection mechanism
5. WHEN creating infrastructure base modules THEN the base module SHALL implement capability contracts for the specific Coder instance environment
6. WHEN creating infrastructure base modules THEN the base module SHALL encode environment dependencies including registries, proxies, base images, AMI hardening, node images, and network policies
7. WHEN composing templates THEN the final runnable template SHALL be composed as: Toolchain Template + Selected Infrastructure Base Module + Controlled Overrides
8. WHEN selecting infrastructure bases THEN instance administrators SHALL select which base module pairs with each toolchain template
9. WHEN controlling overrides THEN template authors SHALL be able to request compute profiles but SHALL NOT bypass identity or network policies unless explicitly permitted
10. WHEN validating composition THEN the system SHALL validate that toolchain template capability requirements are satisfied by the selected infrastructure base module

### Requirement 11d

**User Story:** As a platform engineer, I want a defined contract interface between toolchain templates and infrastructure base modules, so that portability is maintained and composition is predictable.

#### Acceptance Criteria

1. WHEN defining the template contract THEN the system SHALL specify a minimal, stable interface between toolchain and infrastructure layers
2. WHEN specifying toolchain template inputs THEN the contract SHALL include runtime type, compute profile, network egress policy label, persistent home support, identity mode, artifact cache support, and secrets injection mechanism
3. WHEN specifying infrastructure base outputs THEN the contract SHALL include agent endpoint, runtime environment variables, volume mounts, and metadata
4. WHEN specifying infrastructure base inputs THEN the contract SHALL accept workspace name, owner, requested compute, and image/toolchain identifier
5. WHEN versioning toolchain templates THEN toolchain templates SHALL use semantic versioning for toolchain dependencies
6. WHEN versioning infrastructure bases THEN infrastructure base modules SHALL be versioned separately from toolchain templates
7. WHEN recording composition THEN the resolved template SHALL record toolchain template version, infrastructure base version, and resolved artifact identifiers (image digests, AMI IDs)
8. WHEN breaking contract compatibility THEN infrastructure base module changes that break the contract SHALL require a major version bump

### Requirement 11e

**User Story:** As a platform owner, I want to manage infrastructure base modules per Coder instance, so that I can encode environment-specific constraints and maintain upgrade channels.

#### Acceptance Criteria

1. WHEN managing infrastructure bases THEN platform owners SHALL generate and maintain infrastructure base modules scoped to each Coder instance
2. WHEN publishing infrastructure bases THEN platform owners SHALL publish base modules as blessed modules in a registry or catalog scoped to the instance
3. WHEN managing upgrade channels THEN platform owners SHALL maintain upgrade channels (stable, beta, pinned) for infrastructure base modules
4. WHEN documenting infrastructure bases THEN platform owners SHALL document supported capabilities and defaults for each base module
5. WHEN upgrading infrastructure bases THEN platform owners SHALL be able to update infrastructure bases without breaking toolchain template authors unless the contract changes

### Requirement 11f

**User Story:** As a template author, I want to write portable toolchain templates once and deploy them across multiple Coder instances, so that I avoid rewriting templates for each environment.

#### Acceptance Criteria

1. WHEN authoring toolchain templates THEN template authors SHALL write toolchain templates once without infrastructure-specific details
2. WHEN declaring requirements THEN template authors SHALL declare required capabilities and toolchain dependencies in the toolchain manifest
3. WHEN validating toolchain templates THEN template authors SHALL validate templates locally using lint and contract checks before publishing
4. WHEN publishing toolchain templates THEN template authors SHALL publish toolchain templates to a central catalog or Git repository
5. WHEN consuming toolchain templates THEN instance administrators SHALL select the toolchain template version and infrastructure base module pairing for deployment

### Requirement 11g

**User Story:** As a security engineer, I want guardrails on template composition, so that toolchain templates cannot bypass infrastructure security controls.

#### Acceptance Criteria

1. WHEN composing templates THEN toolchain templates SHALL NOT directly declare infrastructure primitives (subnets, security groups, node selectors) except via capability requests
2. WHEN controlling infrastructure THEN infrastructure base modules SHALL control identity bindings, network policy, privileged execution, and mount permissions
3. WHEN validating overrides THEN template overrides SHALL be policy-validated and SHALL NOT allow arbitrary passthrough
4. WHEN managing security THEN toolchain templates SHALL produce artifacts with digest pinning and SBOM generation
5. WHEN enforcing security THEN platform owners SHALL be able to enforce signed images only, approved registries only, and mandatory vulnerability thresholds per channel

### Requirement 11b

**User Story:** As a template administrator, I want a governed template lifecycle, so that templates are properly reviewed, tested, and approved before deployment.

#### Acceptance Criteria

1. WHEN managing templates THEN all toolchain templates and infrastructure base modules SHALL be stored and version-controlled in separate Git repositories
2. WHEN deploying toolchain templates THEN toolchain templates SHALL be validated, tested, approved, and published to a central catalog via CI/CD pipeline
3. WHEN deploying infrastructure bases THEN infrastructure base modules SHALL be validated, tested, approved, and published to the instance-scoped registry via CI/CD pipeline
4. WHEN approving new toolchain templates THEN the platform owner and selected security representative group SHALL approve all new toolchain templates
5. WHEN approving new infrastructure bases THEN the platform owner SHALL approve all new infrastructure base modules
6. WHEN modifying existing templates THEN changes to both toolchain templates and infrastructure bases SHALL follow the same validation, testing, and approval workflow as new templates
7. WHEN auditing template changes THEN all modifications to toolchain templates and infrastructure bases SHALL be traceable through Git history and approval records
8. WHEN managing CVE response THEN toolchain template owners SHALL handle toolchain and dependency CVE updates in the toolchain layer
9. WHEN managing infrastructure security THEN platform owners SHALL handle infrastructure surface area patches (AMI hardening, node images, network posture) in the infrastructure base layer

### Requirement 12

**User Story:** As a security administrator, I want Coder configured with proper authentication, authorization, and encryption, so that the platform meets enterprise security standards.

#### Acceptance Criteria

1. WHEN configuring authentication THEN the system SHALL support any OIDC-capable identity provider selected by the customer
2. WHEN configuring the selected IDP THEN the system SHALL configure appropriate password policies, MFA options, and user attributes
3. WHEN configuring group synchronization THEN the system SHALL use Coder IDP sync to synchronize groups from the selected identity provider
5. WHEN configuring developer workspaces THEN the system SHALL enable external authentication integration for seamless developer access to GitHub source control for users
6. WHEN configuring role-based access THEN the system SHALL implement least-privilege permissions for admins, template admins, organization admins, and developers
7. WHEN configuring traffic encryption THEN the system SHALL enforce HTTPS everywhere with no exceptions
8. WHEN configuring TLS THEN the system SHALL enforce TLS 1.2 minimum with TLS 1.3 preferred
8a. WHEN configuring TLS cipher suites THEN the system SHALL use AES-128-GCM or AES-256-GCM with ECDHE for key exchange per Fortune 2000 standards
9. WHEN configuring database security THEN the Aurora cluster SHALL encrypt database contents at rest using AES-256 and use TLS for the access URL
10. WHEN classifying data THEN the system SHALL be designed to handle company proprietary information as the maximum sensitivity level

### Requirement 12a

**User Story:** As a security administrator, I want comprehensive role-based access control with least-privilege enforcement, so that users have only the permissions necessary for their function.

#### Acceptance Criteria

1. WHEN implementing roles THEN the system SHALL define Owner role limited to 2-3 individuals with full system administration
2. WHEN implementing roles THEN the system SHALL define User Admin role that can create/delete users, manage group membership, and assign Member role
3. WHEN implementing roles THEN the system SHALL define Template Admin role that can create/modify templates and assign template access but cannot modify users
4. WHEN implementing roles THEN the system SHALL define Auditor role with read-only access to audit logs and system metrics
5. WHEN implementing roles THEN the system SHALL define Developer/Member role that can create and manage own workspaces from assigned templates
6. WHEN enforcing least-privilege THEN the system SHALL assign users the minimum role necessary for their function
7. WHEN enforcing segregation of duties THEN Template Admin and User Admin roles SHALL NOT be assigned to the same individual
8. WHEN preventing privilege escalation THEN users SHALL NOT be able to elevate their own permissions
9. WHEN auditing role changes THEN all role assignments SHALL be logged and changes to Owner role SHALL require documented approval
10. WHEN restricting administrative access THEN Coder owners and admins SHALL NOT have access to user workspaces or user workspace data

### Requirement 12b

**User Story:** As a template administrator, I want controlled template access and lifecycle management, so that templates are properly governed and access is auditable.

#### Acceptance Criteria

1. WHEN organizing templates THEN templates SHALL be organized by team, project, or environment
2. WHEN setting default visibility THEN template visibility SHALL default to private, not public to all users
3. WHEN granting template access THEN access SHALL be granted to groups rather than individual users
4. WHEN publishing production templates THEN approval SHALL be required from Template Admin before publication
6. WHEN deprecating templates THEN deprecated templates SHALL be archived and access SHALL be revoked
7. WHEN modifying templates THEN all modifications SHALL be version-controlled and auditable in both git source control and Coder's audit system

### Requirement 12c

**User Story:** As an identity administrator, I want automated group synchronization from the selected IDP, so that access management is centralized and consistent.

#### Acceptance Criteria

1. WHEN synchronizing groups THEN the system SHALL synchronize user groups from the selected identity provider
2. WHEN propagating group changes THEN group membership changes in the IDP SHALL propagate to Coder
3. WHEN sync failures occur THEN the system SHALL generate alerts to the operations team
4. WHEN mapping groups to roles THEN IDP coder-platform-admins group SHALL map to User Admin role
5. WHEN mapping groups to roles THEN IDP coder-template-owners group SHALL map to Template Admin role
6. WHEN mapping groups to roles THEN IDP coder-security-audit group SHALL map to Auditor role
7. WHEN mapping groups to roles THEN IDP developers group SHALL map to Member role
8. WHEN reviewing access THEN group-based access SHALL be reviewed quarterly
9. WHEN provisioning users THEN the system SHALL use IDP sync to automatically provision users and groups from the selected IDP to Coder
10. WHEN deprovisioning users THEN user access SHALL be revoked within 30 days of termination

### Requirement 12d

**User Story:** As a security administrator, I want proper workspace and API access controls, so that workspace access is protected and programmatic access is governed.

#### Acceptance Criteria

1. WHEN assigning workspace ownership THEN each workspace SHALL have a single owner who is the creator
2. WHEN controlling workspace access THEN workspace owners SHALL have full control over their workspaces
3. WHEN authenticating CI/CD systems THEN service account tokens SHALL be used with minimum required permissions
6. WHEN managing service account tokens THEN tokens SHALL expire after 90 days and require rotation
7. WHEN scoping service accounts THEN service accounts for template deployment SHALL have Template Admin scope only
8. WHEN storing tokens THEN API tokens SHALL be stored in AWS Secrets Manager
9. WHEN token compromise occurs THEN immediate revocation and rotation SHALL be triggered

### Requirement 12e

**User Story:** As a security administrator, I want strong authentication controls and session management, so that user access is properly secured.

#### Acceptance Criteria

1. WHEN selecting an IDP THEN the selected identity provider SHALL support the following authentication and logging capabilities:
   - Multi-factor authentication enforcement for all users
   - MFA enforcement at the IDP level before Coder access
   - Session expiration after 8 hours of inactivity
   - Re-authentication requirement after session expiration
   - Concurrent session detection with security alerts for sessions from different locations
   - Logging of failed authentication attempts
   - Account lockout after 5 consecutive failed attempts for 30 minutes
   - Alert generation for account lockout events to the security team

### Requirement 12f

**User Story:** As a platform engineer, I want secure provisioner authentication and isolation, so that provisioners are properly controlled and auditable.

#### Acceptance Criteria

1. WHEN authenticating provisioners THEN external provisioners SHALL authenticate using Coder provisioner keys
2. WHEN rotating provisioner keys THEN keys SHALL be rotated every 90 days
3. WHEN key compromise occurs THEN immediate key revocation and provisioner reprovisioning SHALL be triggered
4. WHEN isolating provisioners THEN provisioners MAY be dedicated to specific organizations or templates using provisioner tags
5. WHEN controlling provisioner scope THEN provisioner access SHALL be controlled via Coder provisioner key scoping and tags
6. WHEN auditing provisioners THEN provisioner access logs SHALL identify which templates were provisioned

### Requirement 12g

**User Story:** As a platform engineer, I want defined integrations with external systems, so that the Coder platform works seamlessly with existing development tools and infrastructure.

#### Acceptance Criteria

1. WHEN integrating with Git providers THEN the system SHALL support and configure integration with the customer's selected Git provider
2. WHEN integrating with CI/CD THEN the system SHALL support CI/CD integration for automated template deployment workflows
3. WHEN integrating with monitoring THEN the system SHALL forward metrics and logs to AWS monitoring services (CloudWatch, X-Ray as applicable)
4. WHEN selecting SSO providers THEN the system SHALL support any OIDC-capable identity provider
5. WHEN configuring developer tooling THEN workspace templates SHALL include Git CLI and authentication pre-configured for the selected provider
6. WHEN integrating with DevSecOps tooling THEN the system SHALL configure Coder external authentication to support seamless access to external services from workspaces

### Requirement 13

**User Story:** As a cost optimization specialist, I want Coder configured with workspace lifecycle management, so that compute resources are used efficiently and costs are minimized.

#### Acceptance Criteria

1. WHEN configuring workspace lifecycle THEN the system SHALL enable auto-start and auto-stop on all workspaces based on idle time detection
2. WHEN scheduling workspace shutdowns THEN the system SHALL automatically stop workspaces at 1800 ET daily
3. WHEN scheduling workspace startups THEN the system SHALL automatically start workspaces at 0700 ET daily
4. WHEN preparing for morning usage THEN the system SHALL pre-provision workspaces and nodes ahead of user activity to reduce startup latency

### Requirement 14

**User Story:** As a capacity planner, I want the deployment sized appropriately for expected workload, so that the platform can handle peak usage without over-provisioning.

#### Acceptance Criteria

1. WHEN sizing for peak capacity THEN the system SHALL support up to 3000 workspaces or approximately 1000 users during working hours 0700-1800 ET
2. WHEN sizing for off-hours capacity THEN the system SHALL support up to 300 workspaces or approximately 100 users outside working hours
3. WHEN calculating user workspace allocation THEN the system SHALL assume approximately 3 workspaces per user
4. WHEN sizing infrastructure THEN the system SHALL use Software Developer (Medium) / Platform Engineer (Standard) sizing of 4 vCPU, 8GB RAM, and 100GB storage as the average workspace for instance and node capacity calculations
5. WHEN configuring workspace storage THEN the system SHALL use block storage for optimal read/write performance
6. WHEN provisioning pod-based workspaces THEN the system SHALL complete provisioning in less than 2 minutes
7. WHEN provisioning EC2-based workspaces THEN the system SHALL complete provisioning in less than 5 minutes
7a. WHEN provisioning GPU-enabled workspaces THEN the system SHALL complete provisioning in up to 5 minutes depending on GPU availability since GPU nodes are not pre-warmed
8. WHEN starting stopped workspaces THEN the system SHALL make workspaces accessible in less than 2 minutes
9. WHEN measuring API performance THEN the system SHALL achieve P95 API response time of less than 500 milliseconds
10. WHEN measuring API performance THEN the system SHALL achieve P99 API response time of less than 1 second
11. WHEN handling concurrent provisioning THEN the system SHALL support 1000 simultaneous workspace provisioning operations
12. WHEN authenticating users THEN the system SHALL complete IDP authentication in less than 800 milliseconds
13. WHEN monitoring performance THEN the system SHALL track API latency metrics for performance monitoring
14. WHEN defining maximum capacity THEN the system SHALL support an upper bound of 3000 concurrently running workspaces
15. WHEN limiting per-user workspaces THEN the system SHALL enforce a maximum of 3 workspaces per user
16. WHEN sizing workspace resources THEN the system SHALL support the following t-shirt sized workspace configurations:
    - Software Developer (Small): 2 vCPU, 4GB RAM, 20GB storage
    - Software Developer (Medium): 4 vCPU, 8GB RAM, 50GB storage
    - Software Developer (Large): 8 vCPU, 16GB RAM, 100GB storage
    - Platform Engineer / DevSecOps (Standard): 4 vCPU, 8GB RAM, 100GB storage
    - Data Science / AI Engineer (Standard): 8 vCPU, 32GB RAM, 500GB storage
    - Data Science / AI Engineer (Large): 16 vCPU, 64GB RAM, 1TB storage, GPU optional
    - Data Science / AI Engineer (XLarge): 32 vCPU, 64GB RAM, 2TB storage, 1-N GPUs
17. WHEN controlling access to large resources THEN access to larger workspace configurations SHALL be controlled via template access permissions
18. WHEN responding to demand changes THEN workspace capacity SHALL scale to accommodate demand within 5 minutes
19. WHEN executing scheduled scaling THEN scheduled capacity changes SHALL complete 15 minutes before the scheduled time
20. WHEN scaling delays occur THEN delays exceeding targets SHALL generate operational alerts

### Requirement 15

**User Story:** As a deployment operator, I want opinionated Helm values files for all Coder components, so that I can deploy with production-ready configurations without extensive customization.

#### Acceptance Criteria

1. WHEN deploying Coder THEN the Deployment Guide and IaC SHALL include an opinionated values.yaml file for the Coder Helm chart with production-ready settings
2. WHEN deploying external provisioners THEN the Deployment Guide and IaC SHALL include an opinionated values.yaml file for the coder-provisioner Helm chart
2a. WHEN deploying the observability stack THEN the Deployment Guide and IaC SHALL include an opinionated values.yaml file for the Coder observability components
3. WHEN configuring Helm values THEN the values files SHALL include all settings required to meet the security, scaling, and authentication requirements defined in this document
4. WHEN documenting Helm values THEN the Deployment Guide SHALL explain each significant configuration option and its purpose
4a. WHEN targeting documentation audience THEN documentation SHALL be written for DevSecOps Engineers L1-5 and SysAdmins L3-L6
4b. WHEN publishing documentation THEN the Deployment Guide SHALL be published on coder.com/docs with supporting markdown files in the IaC repositories
4c. WHEN maintaining documentation THEN Coder SHALL own and maintain all documentation
5. WHEN providing values files THEN the IaC SHALL include parameterized templates that allow environment-specific customization while maintaining opinionated defaults

### Requirement 16

**User Story:** As a platform engineer, I want Terraform-based IaC and comprehensive documentation, so that I can deploy and manage the Coder platform declaratively.

#### Acceptance Criteria

1. WHEN delivering the solution THEN the system SHALL provide a comprehensive deployment guide with architectural diagrams, code snippets, and links to Coder and AWS documentation
2. WHEN delivering IaC THEN the system SHALL provide a Terraform repository with HCL implementation for all infrastructure components
3. WHEN configuring Coder THEN the system SHALL use the coderd Terraform provider for declarative Coder configuration (templates, users, groups, settings)
4. WHEN structuring the IaC repository THEN the repository SHALL include README documentation, example configurations, and deployment instructions
5. WHEN managing Day 0/1/2 operations THEN Terraform SHALL handle infrastructure provisioning (Day 0), initial configuration (Day 1), and ongoing management (Day 2)


### Requirement 17

**User Story:** As a procurement manager, I want clear licensing and support requirements, so that I can ensure proper licensing and support agreements are in place.

#### Acceptance Criteria

1. WHEN licensing Coder THEN the deployment SHALL require Coder Premium license to support pre-builds and other premium features
2. WHEN counting licensed users THEN all users accessing the platform SHALL be licensed
3. WHEN obtaining Coder support THEN the deployment SHALL include Coder Premium support level
4. WHEN documenting licensing THEN the Deployment Guide SHALL reference Coder licensing documentation and feature availability by tier
