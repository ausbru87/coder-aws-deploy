# Coder Provisioner Helm Values Template
# Configuration for external provisioner deployment
#
# Requirements covered:
# - 11.1: External provisioners deployed separately from coderd
# - 15.2: Opinionated values file for coder-provisioner Helm chart
# - 12f.1-12f.6: Provisioner key authentication and scoping
# - 2.5: Least-privilege IAM roles via IRSA

coder:
  # ==========================================================================
  # Replica Configuration
  # Provisioners scale based on time-based schedules (Requirement 4.2)
  # ==========================================================================
  replicaCount: ${provisioner_replicas}

  image:
    tag: "${coder_image_tag}"
    pullPolicy: IfNotPresent

  env:
    # ========================================================================
    # Coder Connection
    # Requirement 11.1: External provisioners connect to coderd
    # ========================================================================
    - name: CODER_URL
      value: "${coder_url}"

    # ========================================================================
    # Provisioner Key Authentication
    # Requirement 12f.1: External provisioners authenticate using provisioner keys
    # Key rotation: 90 days (Requirement 12f.2)
    # ========================================================================
    - name: CODER_PROVISIONER_KEY
      valueFrom:
        secretKeyRef:
          name: ${provisioner_key_secret_name}
          key: key

    # ========================================================================
    # Provisioner Tags for Isolation
    # Requirement 12f.4: Tag-based organization/template isolation
    # Tags control which templates this provisioner can build
    # ========================================================================
    - name: CODER_PROVISIONER_TAGS
      value: "${provisioner_tags}"

    # ========================================================================
    # Provisioner Configuration
    # ========================================================================
    # Number of concurrent jobs per provisioner pod
    - name: CODER_PROVISIONER_DAEMON_POLL_INTERVAL
      value: "${poll_interval}"
    
    # Poll jitter to prevent thundering herd
    - name: CODER_PROVISIONER_DAEMON_POLL_JITTER
      value: "${poll_jitter}"

    # ========================================================================
    # Logging and Access Auditing
    # Requirement 12f.6: Provisioner access logs identify templates provisioned
    # ========================================================================
    - name: CODER_VERBOSE
      value: "${verbose_logging}"
    
    # Log format for structured logging
    - name: CODER_LOG_HUMAN
      value: "${log_human}"
    
    # Enable detailed provisioner logging for audit compliance
    # Logs include: template name, workspace name, owner, provisioning status
    - name: CODER_PROVISIONER_DAEMON_LOG_LEVEL
      value: "${provisioner_log_level}"
    
    # Enable JSON logging for CloudWatch Logs Insights queries
    - name: CODER_LOG_JSON
      value: "${log_json}"

    # ========================================================================
    # Terraform Configuration
    # ========================================================================
    # Terraform plugin cache for faster provisioning
    - name: TF_PLUGIN_CACHE_DIR
      value: "/tmp/terraform-plugin-cache"

  # ==========================================================================
  # Resource Limits
  # Provisioners need significant resources for Terraform operations
  # ==========================================================================
  resources:
    requests:
      cpu: "${provisioner_cpu_request}"
      memory: "${provisioner_memory_request}"
    limits:
      cpu: "${provisioner_cpu_limit}"
      memory: "${provisioner_memory_limit}"

  # ==========================================================================
  # Node Placement
  # Requirement 11.2: Provisioners on separate nodepool (coder-prov)
  # ==========================================================================
  nodeSelector:
    coder.com/node-type: provisioner

  # Toleration for provisioner node taint
  tolerations:
    - key: "coder-prov"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

  # Anti-affinity to spread provisioners across nodes/AZs
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
                    - coder-provisioner
            topologyKey: topology.kubernetes.io/zone

  # ==========================================================================
  # Service Account with IRSA
  # Requirement 2.5, 15.2: CoderProvRole with EC2/EKS provisioning permissions
  # Permissions include:
  # - EC2 provisioning for ec2-* templates
  # - EKS access for pod-* templates
  # - IAM PassRole for workspace roles
  # ==========================================================================
  serviceAccount:
    create: true
    name: coder-provisioner
    annotations:
      eks.amazonaws.com/role-arn: "${service_account_role_arn}"

  # ==========================================================================
  # Pod Disruption Budget
  # Ensure at least one provisioner is always available
  # ==========================================================================
  podDisruptionBudget:
    enabled: true
    minAvailable: 1

  # ==========================================================================
  # Health Checks
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
  # Volume Mounts
  # Terraform plugin cache for faster provisioning
  # ==========================================================================
  volumeMounts:
    - name: terraform-plugin-cache
      mountPath: /tmp/terraform-plugin-cache

  volumes:
    - name: terraform-plugin-cache
      emptyDir:
        sizeLimit: 2Gi

  # ==========================================================================
  # Security Context
  # Run as non-root for security
  # ==========================================================================
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000

  podSecurityContext:
    seccompProfile:
      type: RuntimeDefault
