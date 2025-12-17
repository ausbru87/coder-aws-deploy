# Coder Helm Values Template
# Production configuration for coderd deployment
#
# Requirements covered:
# - 6.2: Multiple replicas with health checks and resource limits
# - 11.1: Internal provisioners set to zero (external provisioners used)
# - 12.1: OIDC authentication with any OIDC-capable IDP
# - 12.5: External authentication for Git provider integration
# - 15.1: Opinionated production-ready values file
# - 12c.1-12c.10: IDP group synchronization configuration
# - 12e.1: Session management (8-hour inactivity timeout)
# - 14.15: Max 3 workspaces per user quota

coder:
  # ==========================================================================
  # Replica Configuration
  # Requirement 6.2: Multiple replicas for high availability
  # ==========================================================================
  replicaCount: ${replicas}

  image:
    # Use specific version tag in production, not "latest"
    tag: "${coder_image_tag}"
    pullPolicy: IfNotPresent

  env:
    # ========================================================================
    # Access URLs
    # ========================================================================
    - name: CODER_ACCESS_URL
      value: "${access_url}"
    - name: CODER_WILDCARD_ACCESS_URL
      value: "${wildcard_access_url}"

    # ========================================================================
    # Database Connection
    # Requirement 3.2: IAM authentication or Secrets Manager for credentials
    # ========================================================================
    - name: CODER_PG_CONNECTION_URL
      valueFrom:
        secretKeyRef:
          name: coder-db-url
          key: url

    # ========================================================================
    # Provisioner Configuration
    # Requirement 11.1: Internal provisioners set to zero
    # External provisioners deployed separately via coder-provisioner chart
    # ========================================================================
    - name: CODER_PROVISIONER_DAEMONS
      value: "0"

    # ========================================================================
    # OIDC Authentication
    # Requirements: 12.1, 12c.1-12c.10
    # Supports any OIDC-capable identity provider
    # ========================================================================
    - name: CODER_OIDC_ISSUER_URL
      value: "${oidc_issuer_url}"
    - name: CODER_OIDC_CLIENT_ID
      value: "${oidc_client_id}"
    - name: CODER_OIDC_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: coder-oidc-credentials
          key: CODER_OIDC_CLIENT_SECRET
    
    # Email domain restriction (empty = allow all domains)
    - name: CODER_OIDC_EMAIL_DOMAIN
      value: "${oidc_email_domain}"
    
    # OIDC scopes - must include 'groups' for group sync
    # Requirement 12c.1: Synchronize user groups from IDP
    - name: CODER_OIDC_SCOPES
      value: "openid,profile,email,groups"
    
    # Group claim name in OIDC token (varies by IDP)
    - name: CODER_OIDC_GROUP_FIELD
      value: "${oidc_group_field}"
    
    # Auto-create groups from IDP
    # Requirement 12c.9: Automatic user provisioning via IDP sync
    - name: CODER_OIDC_GROUP_AUTO_CREATE
      value: "true"
    
    # Group regex filter (optional - filter which groups to sync)
    - name: CODER_OIDC_GROUP_REGEX_FILTER
      value: "${oidc_group_regex_filter}"
    
    # Group mapping (JSON object mapping IDP groups to Coder groups)
    # Requirement 12c.4-12c.7: Map IDP groups to Coder roles
    # Example: {"coder-platform-admins": "user-admin", "coder-template-owners": "template-admin"}
    - name: CODER_OIDC_GROUP_MAPPING
      value: '${oidc_group_mapping}'
    
    # Allow signups via OIDC (new users auto-provisioned)
    - name: CODER_OIDC_ALLOW_SIGNUPS
      value: "true"
    
    # Ignore email verification status from IDP
    - name: CODER_OIDC_IGNORE_EMAIL_VERIFIED
      value: "${oidc_ignore_email_verified}"

    # ========================================================================
    # Session Management
    # Requirement 12e.1: Session expiration after 8 hours of inactivity
    # ========================================================================
    - name: CODER_SESSION_DURATION
      value: "${session_duration}"
    
    # Disable password authentication (OIDC only)
    - name: CODER_DISABLE_PASSWORD_AUTH
      value: "${disable_password_auth}"

    # ========================================================================
    # External Authentication (Git Provider)
    # Requirements: 12.5, 12g.1, 12g.5, 12g.6
    # Enables seamless developer access to Git repositories
    # ========================================================================
    - name: CODER_EXTERNAL_AUTH_0_TYPE
      value: "${external_auth_provider}"
    - name: CODER_EXTERNAL_AUTH_0_ID
      value: "${external_auth_id}"
    - name: CODER_EXTERNAL_AUTH_0_CLIENT_ID
      value: "${external_auth_client_id}"
    - name: CODER_EXTERNAL_AUTH_0_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: coder-external-auth-credentials
          key: CODER_EXTERNAL_AUTH_0_CLIENT_SECRET
          optional: true
    # Scopes for Git provider (varies by provider)
    - name: CODER_EXTERNAL_AUTH_0_SCOPES
      value: "${external_auth_scopes}"
    # Display name in Coder UI
    - name: CODER_EXTERNAL_AUTH_0_DISPLAY_NAME
      value: "${external_auth_display_name}"

    # ========================================================================
    # Workspace Quotas
    # Requirement 14.15: Maximum 3 workspaces per user
    # ========================================================================
    - name: CODER_USER_WORKSPACE_QUOTA
      value: "${max_workspaces_per_user}"

    # ========================================================================
    # Workspace Lifecycle Defaults
    # Requirements: 5.9, 13.1, 13.2
    # Auto-start/auto-stop enabled by default
    # ========================================================================
    - name: CODER_DEFAULT_QUIET_HOURS_SCHEDULE
      value: "${default_quiet_hours_schedule}"

    # ========================================================================
    # Observability
    # Requirements: 8.1a, 15.2a
    # Prometheus metrics export on port 2112
    # ========================================================================
    - name: CODER_PROMETHEUS_ENABLE
      value: "true"
    - name: CODER_PROMETHEUS_ADDRESS
      value: "0.0.0.0:2112"
    - name: CODER_PROMETHEUS_COLLECT_AGENT_STATS
      value: "true"
    - name: CODER_PROMETHEUS_COLLECT_DB_METRICS
      value: "true"

    # ========================================================================
    # Security Configuration
    # Requirements: 12.7, 12.8
    # TLS terminated at NLB, HTTPS enforced everywhere
    # ========================================================================
    - name: CODER_TLS_ENABLE
      value: "false"  # TLS terminated at NLB
    - name: CODER_SECURE_AUTH_COOKIE
      value: "true"
    # HSTS header (1 year)
    - name: CODER_STRICT_TRANSPORT_SECURITY
      value: "31536000"
    - name: CODER_STRICT_TRANSPORT_SECURITY_OPTIONS
      value: "includeSubDomains"
    # Redirect HTTP to HTTPS
    - name: CODER_REDIRECT_TO_ACCESS_URL
      value: "true"

    # ========================================================================
    # DERP/Networking
    # Requirements: 3.1a - DERP relay via NAT Gateway and STUN
    # ========================================================================
    - name: CODER_DERP_SERVER_ENABLE
      value: "true"
    - name: CODER_DERP_SERVER_STUN_ADDRESSES
      value: "${derp_stun_addresses}"
    # Force WebSocket connections (better for corporate firewalls)
    - name: CODER_DERP_FORCE_WEBSOCKETS
      value: "${derp_force_websockets}"

    # ========================================================================
    # Audit Logging
    # Requirements: 3.6, 3.8
    # Coder audit logs forwarded to CloudWatch via Fluent Bit
    # ========================================================================
    - name: CODER_VERBOSE
      value: "${verbose_logging}"

    # ========================================================================
    # Experiments (optional features)
    # ========================================================================
    - name: CODER_EXPERIMENTS
      value: "${experiments}"

  # ==========================================================================
  # Resource Limits
  # Requirement 6.2: Proper resource limits for production
  # ==========================================================================
  resources:
    requests:
      cpu: "${coderd_cpu_request}"
      memory: "${coderd_memory_request}"
    limits:
      cpu: "${coderd_cpu_limit}"
      memory: "${coderd_memory_limit}"

  # ==========================================================================
  # Node Placement
  # Requirement 11.2: coderd on separate nodepool (coder-control)
  # ==========================================================================
  nodeSelector:
    coder.com/node-type: control

  # Toleration for control node taint
  tolerations:
    - key: "coder-control"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

  # Anti-affinity to spread replicas across nodes/AZs
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values:
                    - coder
            topologyKey: topology.kubernetes.io/zone

  # ==========================================================================
  # Pod Disruption Budget
  # Requirement 4.5: Maintain service availability during updates
  # ==========================================================================
  podDisruptionBudget:
    enabled: true
    minAvailable: 1

  # ==========================================================================
  # Health Checks
  # Requirement 6.2: Health checks for coderd
  # ==========================================================================
  livenessProbe:
    httpGet:
      path: /healthz
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3

  readinessProbe:
    httpGet:
      path: /healthz
      port: 8080
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 3

  # ==========================================================================
  # Service Account with IRSA
  # Requirement 2.5: Least-privilege IAM roles via IRSA
  # ==========================================================================
  serviceAccount:
    create: true
    name: coder
    annotations:
      eks.amazonaws.com/role-arn: "${service_account_role_arn}"

# =============================================================================
# Service Configuration
# =============================================================================
service:
  type: ClusterIP
  port: 8080

# =============================================================================
# Metrics Service for Prometheus
# Requirement 8.1a: Prometheus metrics export
# =============================================================================
metrics:
  enabled: true
  port: 2112
